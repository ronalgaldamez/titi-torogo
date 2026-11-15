<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\Backup;
use App\Models\BackupSetting;
use App\Models\User;
use App\Support\BackupService;
use Aws\MockHandler;
use Aws\Result;
use Aws\S3\S3Client;
use Illuminate\Filesystem\AwsS3V3Adapter;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Mockery;
use Symfony\Component\Process\Process;
use Tests\TestCase;

class BackupsTest extends TestCase
{
    use DatabaseMigrations;

    private string $directory;

    private string $uploaded = '';

    private array $uploads = [];

    private ?string $workDirectory = null;

    protected function setUp(): void
    {
        parent::setUp();
        $this->directory = storage_path('framework/testing/backup-'.Str::uuid());
        File::ensureDirectoryExists($this->directory.'/public/landing', 0700);
        File::put($this->directory.'/public/landing/image.txt', 'imagen local de prueba');
        File::put($this->directory.'/.env', 'SECRETO_NO_INCLUIR');
        config([
            'filesystems.disks.backups.key' => 'backup-test-key',
            'filesystems.disks.backups.secret' => 'backup-test-secret',
            'filesystems.disks.backups.bucket' => 'torogo-backups-test',
            'filesystems.disks.public.root' => $this->directory.'/public',
        ]);
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->directory);
        parent::tearDown();
    }

    private function service(bool $badChecksum = false): BackupService
    {
        $callback = function ($command) use ($badChecksum) {
            $this->assertArrayNotHasKey('ACL', $command->toArray());
            $this->assertSame('torogo-backups-test', $command['Bucket']);
            $this->assertStringStartsWith('backups/', $command['Key']);
            if ($command->getName() === 'PutObject') {
                $this->uploaded = (string) $command['Body'];
                $this->uploads[] = $command['Key'];
                $this->assertSame('AES256', $command['ServerSideEncryption']);
                $this->assertSame(base64_encode(hash('sha256', $this->uploaded, true)), $command['ChecksumSHA256']);

                return new Result;
            }

            return new Result([
                'ContentLength' => strlen($this->uploaded),
                'ChecksumSHA256' => $badChecksum ? 'incorrecto' : base64_encode(hash('sha256', $this->uploaded, true)),
            ]);
        };
        $client = new S3Client([
            'version' => 'latest', 'region' => 'us-east-2',
            'credentials' => ['key' => 'test-key', 'secret' => 'test-secret'],
            'handler' => new MockHandler(array_fill(0, 12, $callback)),
        ]);
        $disk = Mockery::mock(AwsS3V3Adapter::class);
        $disk->shouldReceive('getClient')->andReturn($client);
        Storage::shouldReceive('disk')->with('backups')->andReturn($disk);
        $service = Mockery::mock(BackupService::class)->makePartial()->shouldAllowMockingProtectedMethods();
        $service->shouldReceive('dump')->andReturnUsing(function ($file) {
            $this->workDirectory = dirname($file);
            File::put($file, 'PGDMP-test-database');
        });

        return $service;
    }

    public function test_only_admin_can_view_request_configure_or_download_backups(): void
    {
        $backup = Backup::create(['source' => 'manual']);
        foreach ([null, 'client', 'restaurant', 'courier'] as $role) {
            if ($role !== null) {
                $user = User::factory()->create();
                $user->role = UserRole::from($role);
                $user->save();
                $this->actingAs($user, 'web');
            }
            foreach (['get' => '/admin/respaldos', 'post' => '/admin/respaldos', 'put' => '/admin/respaldos/programacion',
                'download' => '/admin/respaldos/'.$backup->id.'/descargar'] as $method => $url) {
                $response = $this->{$method === 'download' ? 'get' : $method}($url);
                $role === null ? $response->assertRedirect('/admin/login') : $response->assertForbidden();
            }
        }
        $this->actingAs(User::factory()->admin()->create(), 'web')->get('/admin/respaldos')
            ->assertOk()->assertSee('03:00')->assertSee('Respaldar ahora')
            ->assertDontSee('backup-test-key')->assertDontSee('backup-test-secret');
        $this->assertDatabaseCount('backups', 1);
    }

    public function test_manual_requests_do_not_run_in_the_web_request_or_duplicate_active_work(): void
    {
        $this->actingAs(User::factory()->admin()->create(), 'web');
        $this->post('/admin/respaldos')->assertRedirect('/admin/respaldos')->assertSessionHas('status');
        $this->assertDatabaseHas('backups', ['source' => 'manual', 'status' => 'pending']);
        $this->post('/admin/respaldos')->assertSessionHas('error');
        $this->assertDatabaseCount('backups', 1);
        $this->assertFalse(BackupSetting::current()->enabled);
    }

    public function test_settings_validate_time_and_require_a_separate_configured_bucket(): void
    {
        $this->actingAs(User::factory()->admin()->create(), 'web');
        $this->put('/admin/respaldos/programacion', ['enabled' => true, 'time' => '25:99'])
            ->assertSessionHasErrors('time');
        $this->put('/admin/respaldos/programacion', ['enabled' => true, 'time' => '03:00'])->assertSessionHas('status');
        $this->assertTrue(BackupSetting::current()->enabled);
        config(['filesystems.disks.backups.bucket' => config('filesystems.disks.s3.bucket')]);
        $this->post('/admin/respaldos')->assertSessionHasErrors('backup');
        $this->put('/admin/respaldos/programacion', ['enabled' => true, 'time' => '04:00'])->assertSessionHasErrors('backup');
        $this->put('/admin/respaldos/programacion', ['enabled' => false, 'time' => '04:00'])->assertSessionHas('status');
        $this->assertDatabaseCount('backups', 0);
    }

    public function test_archive_contains_database_and_public_files_without_env_and_is_verified_before_success(): void
    {
        $service = $this->service();
        $backup = $service->request('manual');
        $this->assertTrue($service->run());
        $backup->refresh();
        $this->assertSame('succeeded', $backup->status);
        $this->assertSame(strlen($this->uploaded), $backup->bytes);
        $this->assertSame(hash('sha256', $this->uploaded), $backup->sha256);
        $this->assertCount(1, $this->uploads);
        $this->assertDirectoryDoesNotExist($this->workDirectory);
        File::put($this->directory.'/backup.tar.gz', $this->uploaded);
        File::ensureDirectoryExists($this->directory.'/restored');
        (new Process(['tar', '-xzf', $this->directory.'/backup.tar.gz', '-C', $this->directory.'/restored']))->mustRun();
        $this->assertSame('PGDMP-test-database', File::get($this->directory.'/restored/database.dump'));
        $this->assertSame('imagen local de prueba', File::get($this->directory.'/restored/public/landing/image.txt'));
        $this->assertFileDoesNotExist($this->directory.'/restored/.env');
        $manifest = json_decode(File::get($this->directory.'/restored/manifest.json'), true);
        $this->assertSame(hash('sha256', 'PGDMP-test-database'), $manifest['database_sha256']);
    }

    public function test_failed_integrity_does_not_mark_success_or_expose_credentials(): void
    {
        $service = $this->service(badChecksum: true);
        $backup = $service->request('manual');
        $this->assertFalse($service->run());
        $backup->refresh();
        $this->assertSame('failed', $backup->status);
        $this->assertNull($backup->path);
        $this->actingAs(User::factory()->admin()->create(), 'web')->get('/admin/respaldos')
            ->assertOk()->assertSee('Falló el último respaldo')->assertDontSee('backup-test-secret');
        $this->get('/admin/respaldos/'.$backup->id.'/descargar')->assertNotFound();
        $this->assertNotNull($service->request('manual'));
    }

    public function test_schedule_uses_el_salvador_and_runs_once_per_day_without_admin_session(): void
    {
        $service = $this->service();
        $settings = BackupSetting::current();
        $settings->enabled = true;
        $settings->save();
        $this->travelTo(Carbon::parse('2026-11-14T08:59:00Z'));
        $this->assertTrue($service->run());
        $this->assertDatabaseCount('backups', 0);
        $this->travelTo(Carbon::parse('2026-11-14T09:00:00Z'));
        $this->assertTrue($service->run());
        $this->assertTrue($service->run());
        $this->assertDatabaseCount('backups', 1);
        $this->assertDatabaseHas('backups', ['source' => 'scheduled', 'status' => 'succeeded']);
        $this->travelTo(Carbon::parse('2026-11-15T10:00:00Z'));
        $this->assertTrue($service->run());
        $this->assertDatabaseCount('backups', 2);
        $this->assertCount(2, array_unique($this->uploads));
    }

    public function test_worker_lock_prevents_two_concurrent_runs(): void
    {
        $service = $this->service();
        $service->request('manual');
        $lock = Cache::lock('backups:run', 3600);
        $this->assertTrue($lock->get());
        try {
            $this->assertTrue($service->run());
            $this->assertDatabaseHas('backups', ['status' => 'pending']);
            $this->assertCount(0, $this->uploads);
        } finally {
            $lock->release();
        }
        $this->assertTrue($service->run());
        $this->assertCount(1, $this->uploads);
    }

    public function test_dump_failure_is_recorded_without_upload_and_private_temporaries_are_removed(): void
    {
        Storage::shouldReceive('disk')->never();
        $service = Mockery::mock(BackupService::class)->makePartial()->shouldAllowMockingProtectedMethods();
        $service->shouldReceive('dump')->andReturnUsing(function ($file) {
            $this->workDirectory = dirname($file);
            File::put($file, 'copia incompleta');
            throw new \RuntimeException('Detalle privado del servidor');
        });
        $backup = $service->request('manual');
        $this->assertFalse($service->run());
        $backup->refresh();
        $this->assertSame('failed', $backup->status);
        $this->assertNull($backup->path);
        $this->assertStringNotContainsString('Detalle privado', $backup->error);
        $this->assertDirectoryDoesNotExist($this->workDirectory);
        $this->assertNotNull($service->request('manual'));
    }

    public function test_admin_download_is_private_and_unavailable_after_retention(): void
    {
        Storage::fake('backups');
        Storage::disk('backups')->put('backups/test.tar.gz', 'archivo privado');
        $backup = Backup::create(['source' => 'manual']);
        $backup->forceFill([
            'status' => 'succeeded', 'path' => 'backups/test.tar.gz', 'finished_at' => now(),
            'sha256' => hash('sha256', 'archivo privado'), 'bytes' => strlen('archivo privado'),
        ])->save();
        $this->actingAs(User::factory()->admin()->create(), 'web');
        $response = $this->get('/admin/respaldos/'.$backup->id.'/descargar');
        $response->assertOk()->assertDownload('torogo-backup-'.$backup->id.'.tar.gz')->assertStreamedContent('archivo privado');
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $this->travel(30)->days();
        $this->get('/admin/respaldos/'.$backup->id.'/descargar')->assertNotFound();
    }

    public function test_interrupted_run_is_marked_failed_and_can_be_requested_again(): void
    {
        $backup = Backup::create(['source' => 'manual']);
        $backup->forceFill(['status' => 'running', 'started_at' => now()->subHours(2)])->save();
        $service = new BackupService;
        $this->assertTrue($service->run());
        $this->assertSame('failed', $backup->fresh()->status);
        $this->assertNotNull($service->request('manual'));
    }
}
