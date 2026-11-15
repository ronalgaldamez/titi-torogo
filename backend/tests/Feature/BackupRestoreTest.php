<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\BackupService;
use Aws\Result;
use Aws\S3\S3Client;
use Illuminate\Filesystem\AwsS3V3Adapter;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Mockery;
use Symfony\Component\Process\Process;
use Tests\TestCase;

class BackupRestoreTest extends TestCase
{
    private array $databases = [];

    private ?string $directory = null;

    protected function tearDown(): void
    {
        try {
            DB::purge('pgsql');
            DB::purge('backup_restore');
            foreach ($this->databases as $database) {
                DB::connection('backup_test_admin')->statement('DROP DATABASE IF EXISTS "'.$database.'" WITH (FORCE)');
            }
            DB::purge('backup_test_admin');
            if ($this->directory !== null) {
                File::deleteDirectory($this->directory);
            }
        } finally {
            parent::tearDown();
        }
    }

    public function test_real_postgresql_dump_can_be_restored_with_its_local_images(): void
    {
        if (! env('BACKUP_TEST_DATABASE')) {
            $this->markTestSkipped('Requiere BACKUP_TEST_DATABASE, PostgreSQL y pg_dump/pg_restore 18. Ver BACKUPS.md.');
        }
        $this->assertTrue(app()->environment('testing'));
        $config = config('database.connections.pgsql');
        $config['url'] = null;
        $config['database'] = env('BACKUP_TEST_DATABASE');
        config(['database.connections.backup_test_admin' => $config]);
        $prefix = 'torogo_backup_test_'.bin2hex(random_bytes(6));
        foreach ([$prefix.'_source', $prefix.'_restore'] as $database) {
            DB::connection('backup_test_admin')->statement('CREATE DATABASE "'.$database.'"');
            $this->databases[] = $database;
        }
        $config['database'] = $this->databases[0];
        config(['database.default' => 'pgsql', 'database.connections.pgsql' => $config]);
        DB::purge('pgsql');
        $this->assertSame($this->databases[0], DB::selectOne('SELECT current_database() AS name')->name);
        $this->artisan('migrate', ['--database' => 'pgsql', '--force' => true])->assertExitCode(0);
        $user = User::factory()->create(['name' => 'Cliente de restauración aislada']);
        $this->directory = storage_path('framework/testing/restore-'.Str::uuid());
        File::ensureDirectoryExists($this->directory.'/public/landing', 0700);
        File::put($this->directory.'/public/landing/test.txt', 'imagen recuperable');
        File::put($this->directory.'/.env', 'NO_INCLUIR_SECRETOS');
        config([
            'filesystems.disks.public.root' => $this->directory.'/public',
            'filesystems.disks.backups.key' => 'test-key',
            'filesystems.disks.backups.secret' => 'test-secret',
            'filesystems.disks.backups.bucket' => 'backup-restore-test',
        ]);
        $archive = null;
        $client = Mockery::mock(S3Client::class);
        $client->shouldReceive('putObject')->once()->andReturnUsing(function ($request) use (&$archive) {
            $this->assertArrayNotHasKey('ACL', $request);
            $archive = File::get($request['SourceFile']);
            $this->assertSame(base64_encode(hash('sha256', $archive, true)), $request['ChecksumSHA256']);

            return new Result;
        });
        $client->shouldReceive('headObject')->once()->andReturnUsing(function () use (&$archive) {
            return new Result([
                'ContentLength' => strlen($archive),
                'ChecksumSHA256' => base64_encode(hash('sha256', $archive, true)),
            ]);
        });
        $disk = Mockery::mock(AwsS3V3Adapter::class);
        $disk->shouldReceive('getClient')->andReturn($client);
        Storage::shouldReceive('disk')->with('backups')->andReturn($disk);

        $service = new BackupService;
        $backup = $service->request('manual');
        $this->assertTrue($service->run());
        $this->assertSame('succeeded', $backup->fresh()->status);
        File::put($this->directory.'/backup.tar.gz', $archive);
        File::ensureDirectoryExists($this->directory.'/restored', 0700);
        (new Process(['tar', '-xzf', $this->directory.'/backup.tar.gz', '-C', $this->directory.'/restored']))->mustRun();
        $manifest = json_decode(File::get($this->directory.'/restored/manifest.json'), true);
        $this->assertSame($manifest['database_sha256'], hash_file('sha256', $this->directory.'/restored/database.dump'));
        (new Process([
            'pg_restore', '--exit-on-error', '--no-owner', '--no-acl',
            '--dbname='.$this->databases[1], $this->directory.'/restored/database.dump',
        ], null, [
            'PGHOST' => $config['host'], 'PGPORT' => (string) $config['port'],
            'PGUSER' => $config['username'], 'PGPASSWORD' => $config['password'],
            'PGSSLMODE' => $config['sslmode'] ?? 'prefer', 'PGCONNECT_TIMEOUT' => '10',
        ]))->setTimeout(600)->mustRun();
        $config['database'] = $this->databases[1];
        config(['database.connections.backup_restore' => $config]);
        $this->assertSame($user->name, DB::connection('backup_restore')->table('users')->where('id', $user->id)->value('name'));
        $this->assertSame('imagen recuperable', File::get($this->directory.'/restored/public/landing/test.txt'));
        $this->assertFileDoesNotExist($this->directory.'/restored/.env');
    }
}
