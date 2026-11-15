<?php

namespace App\Support;

use App\Models\Backup;
use App\Models\BackupSetting;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Symfony\Component\Process\Process;
use Throwable;

class BackupService
{
    public static function configured(): bool
    {
        $disk = config('filesystems.disks.backups');

        return filled($disk['key'] ?? null) && filled($disk['secret'] ?? null)
            && filled($disk['bucket'] ?? null)
            && $disk['bucket'] !== config('filesystems.disks.s3.bucket');
    }

    public function request(string $source): ?Backup
    {
        BackupSetting::current();

        return DB::transaction(function () use ($source) {
            BackupSetting::query()->lockForUpdate()->findOrFail(1);
            if (Backup::whereIn('status', ['pending', 'running'])->exists()) {
                return null;
            }

            return Backup::create(['source' => $source]);
        });
    }

    public function run(): bool
    {
        $lock = Cache::lock('backups:run', 3600);
        if (! $lock->get()) {
            return true;
        }
        try {
            Backup::where('status', 'running')->where('started_at', '<', now()->subHour())
                ->update(['status' => 'failed', 'error' => 'El proceso se interrumpió. Generá una copia nueva.', 'finished_at' => now()]);
            $this->schedule();
            $backup = Backup::where('status', 'pending')->oldest('id')->first();
            if ($backup === null) {
                return true;
            }
            $backup->status = 'running';
            $backup->started_at = now();
            $backup->save();

            return $this->create($backup);
        } finally {
            $lock->release();
        }
    }

    private function schedule(): void
    {
        BackupSetting::current();
        DB::transaction(function () {
            $settings = BackupSetting::query()->lockForUpdate()->findOrFail(1);
            $local = now('America/El_Salvador');
            if (! $settings->enabled || $local->format('H:i') < $settings->time
                || $settings->last_scheduled_on === $local->toDateString()
                || Backup::whereIn('status', ['pending', 'running'])->exists()) {
                return;
            }
            Backup::create(['source' => 'scheduled']);
            $settings->last_scheduled_on = $local->toDateString();
            $settings->save();
        });
    }

    private function create(Backup $backup): bool
    {
        $directory = storage_path('app/private/backup-work/'.Str::uuid());
        try {
            if (! self::configured()) {
                throw new RuntimeException('Falta configurar el bucket exclusivo de respaldos.');
            }
            File::ensureDirectoryExists($directory, 0700);
            chmod($directory, 0700);
            $archive = $directory.'/backup.tar.gz';
            $public = rtrim(config('filesystems.disks.public.root'), '/');
            DB::transaction(function () use ($directory, $archive, $backup, $public) {
                if (DB::connection()->getDriverName() === 'pgsql') {
                    // Conserva las referencias a imágenes locales mientras se copian sus archivos.
                    DB::statement('LOCK TABLE landing_pages, restaurant_categories IN SHARE MODE');
                }
                $this->dump($directory.'/database.dump');
                if (! is_file($directory.'/database.dump') || filesize($directory.'/database.dump') === 0) {
                    throw new RuntimeException('El archivo de PostgreSQL está vacío.');
                }
                File::put($directory.'/manifest.json', json_encode([
                    'format' => 1, 'backup_id' => $backup->id, 'created_at' => now()->toISOString(),
                    'database_sha256' => hash_file('sha256', $directory.'/database.dump'),
                    'includes' => ['PostgreSQL', 'storage/app/public'],
                    'excludes' => ['.env', 'images-in-s3'],
                ], JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));
                (new Process([
                    'tar', '-czf', $archive, '-C', $directory, 'database.dump', 'manifest.json',
                    '-C', dirname($public), basename($public),
                ]))->setTimeout(600)->mustRun();
            });
            $bytes = filesize($archive);
            // shortcut: PutObject admite hasta 5 GB; usar multipart cuando las copias alcancen ese tamaño.
            if ($bytes === false || $bytes === 0 || $bytes > 5 * 1024 ** 3) {
                throw new RuntimeException('Tamaño de respaldo no admitido.');
            }
            $sha256 = hash_file('sha256', $archive);
            $checksum = base64_encode(hex2bin($sha256));
            $key = 'backups/'.now('UTC')->format('Y/m/d').'/'.Str::uuid().'.tar.gz';
            $client = Storage::disk('backups')->getClient();
            $bucket = config('filesystems.disks.backups.bucket');
            // Sin ACL: el bucket usa propiedad aplicada al propietario.
            $client->putObject([
                'Bucket' => $bucket, 'Key' => $key, 'SourceFile' => $archive,
                'ContentType' => 'application/gzip', 'ServerSideEncryption' => 'AES256',
                'ChecksumSHA256' => $checksum,
            ]);
            $stored = $client->headObject(['Bucket' => $bucket, 'Key' => $key, 'ChecksumMode' => 'ENABLED']);
            if ((int) $stored['ContentLength'] !== $bytes || ($stored['ChecksumSHA256'] ?? null) !== $checksum) {
                throw new RuntimeException('S3 no confirmó el tamaño y la integridad del respaldo.');
            }
            $backup->status = 'succeeded';
            $backup->path = $key;
            $backup->bytes = $bytes;
            $backup->sha256 = $sha256;
            $backup->finished_at = now();
            $backup->save();

            return true;
        } catch (Throwable $error) {
            report($error);
            $backup->status = 'failed';
            $backup->error = 'No se completó el respaldo. Revisá el registro del servidor y volvé a intentarlo.';
            $backup->finished_at = now();
            $backup->save();

            return false;
        } finally {
            File::deleteDirectory($directory);
        }
    }

    protected function dump(string $file): void
    {
        $database = DB::connection()->getConfig();
        if ($database['driver'] !== 'pgsql') {
            throw new RuntimeException('Los respaldos requieren PostgreSQL.');
        }
        (new Process(['pg_dump', '--format=custom', '--no-owner', '--no-acl', '--file='.$file], null, [
            'PGHOST' => $database['host'], 'PGPORT' => (string) $database['port'],
            'PGDATABASE' => $database['database'], 'PGUSER' => $database['username'],
            'PGPASSWORD' => $database['password'], 'PGSSLMODE' => $database['sslmode'] ?? 'prefer',
            'PGCONNECT_TIMEOUT' => '10',
        ]))->setTimeout(600)->mustRun();
    }
}
