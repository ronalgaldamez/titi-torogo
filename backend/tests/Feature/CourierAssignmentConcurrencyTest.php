<?php

namespace Tests\Feature;

use App\Events\CouriersUpdated;
use App\Events\OrderUpdated;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class CourierAssignmentConcurrencyTest extends TestCase
{
    private ?string $schema = null;

    protected function setUp(): void
    {
        parent::setUp();
        if (! env('CONCURRENCY_DB_DATABASE') || ! function_exists('pcntl_fork')) {
            $this->markTestSkipped('Requiere PostgreSQL, pcntl y CONCURRENCY_DB_DATABASE. Ver COURIER_GPS.md.');
        }
        $this->assertTrue(app()->environment('testing'));
        config([
            'database.default' => 'pgsql',
            'database.connections.pgsql.url' => null,
            'database.connections.pgsql.database' => env('CONCURRENCY_DB_DATABASE'),
        ]);
        DB::purge('pgsql');
        $this->schema = 'courier_test_'.bin2hex(random_bytes(8));
        DB::statement('CREATE SCHEMA "'.$this->schema.'"');
        // Nunca se migran ni borran las tablas del esquema público.
        config(['database.connections.pgsql.search_path' => $this->schema]);
        DB::purge('pgsql');
        $this->assertSame($this->schema, DB::selectOne('SELECT current_schema() AS name')->name);
        $this->artisan('migrate', ['--database' => 'pgsql', '--force' => true])->assertExitCode(0);
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
    }

    protected function tearDown(): void
    {
        try {
            if ($this->schema !== null) {
                DB::statement('DROP SCHEMA "'.$this->schema.'" CASCADE');
                DB::purge('pgsql');
            }
        } finally {
            parent::tearDown();
        }
    }

    public static function assignmentPairs(): array
    {
        return [
            'dos tomas' => ['take', 'take'],
            'toma y administrador' => ['take', 'admin'],
            'dos asignaciones administrativas' => ['admin', 'admin'],
        ];
    }

    #[DataProvider('assignmentPairs')]
    public function test_only_one_simultaneous_assignment_succeeds(string $first, string $second): void
    {
        $courier = User::factory()->courier()->create();
        $admin = User::factory()->admin()->create();
        $client = User::factory()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => User::factory()->restaurant()->create()->id,
            'name' => 'Local de prueba', 'address' => 'Centro', 'phone' => '70000000',
            'latitude' => 14.1, 'longitude' => -89.1, 'is_active' => true,
        ]);
        $orders = [];
        foreach ([1, 2] as $number) {
            $orders[] = DB::table('orders')->insertGetId([
                'user_id' => $client->id, 'restaurant_id' => $restaurant,
                'status' => 'ready', 'delivery_address' => 'Casa de prueba',
                'delivery_latitude' => 14.2, 'delivery_longitude' => -89.2,
                'subtotal' => '4.00', 'delivery_fee' => '2.00', 'courier_fee' => '1.50',
                'platform_fee' => '0.50', 'total' => '6.00',
                'idempotency_key' => 'concurrent-'.$number,
            ]);
        }
        // Se abren conexiones nuevas después del fork; no se comparte un socket PDO.
        DB::disconnect('pgsql');
        $workers = [];
        try {
            foreach ([$first, $second] as $index => $action) {
                $pipes = stream_socket_pair(STREAM_PF_UNIX, STREAM_SOCK_STREAM, STREAM_IPPROTO_IP);
                $this->assertNotFalse($pipes);
                $name = $this->schema.'_'.$index;
                $pid = pcntl_fork();
                $this->assertNotSame(-1, $pid);
                if ($pid === 0) {
                    fclose($pipes[0]);
                    try {
                        stream_set_timeout($pipes[1], 15);
                        if (fgets($pipes[1]) !== "start\n") {
                            throw new \RuntimeException('No se recibió la señal de inicio.');
                        }
                        DB::select("SELECT set_config('application_name', ?, false)", [$name]);
                        DB::statement("SET statement_timeout = '10s'");
                        if ($action === 'take') {
                            Sanctum::actingAs($courier);
                            $status = $this->postJson('/api/courier/orders/'.$orders[$index].'/take')->status();
                        } else {
                            $this->actingAs($admin, 'web')->post(
                                '/admin/pedidos/'.$orders[$index].'/motorizado',
                                ['courier_id' => $courier->id],
                            )->assertRedirect();
                            $status = session()->has('error') ? 422 : 200;
                        }
                        fwrite($pipes[1], json_encode(['status' => $status])."\n");
                        DB::disconnect('pgsql');
                        exit(0);
                    } catch (\Throwable $error) {
                        fwrite($pipes[1], json_encode(['error' => $error->getMessage()])."\n");
                        exit(1);
                    }
                }
                fclose($pipes[1]);
                stream_set_timeout($pipes[0], 15);
                $workers[] = ['pid' => $pid, 'pipe' => $pipes[0], 'name' => $name];
            }

            $blocked = 0;
            DB::beginTransaction();
            try {
                User::query()->whereKey($courier->id)->lockForUpdate()->firstOrFail();
                foreach ($workers as $worker) {
                    fwrite($worker['pipe'], "start\n");
                }
                $deadline = microtime(true) + 5;
                do {
                    DB::select('SELECT pg_stat_clear_snapshot()');
                    $blocked = (int) DB::selectOne(
                        "SELECT count(*) AS total FROM pg_stat_activity WHERE application_name IN (?, ?) AND wait_event_type = 'Lock'",
                        array_column($workers, 'name'),
                    )->total;
                    if ($blocked === 2) {
                        break;
                    }
                    usleep(10000);
                } while (microtime(true) < $deadline);
            } finally {
                DB::rollBack();
            }

            $statuses = [];
            foreach ($workers as $worker) {
                $result = json_decode(fgets($worker['pipe']) ?: '{}', true);
                $this->assertArrayHasKey('status', $result, json_encode($result));
                $statuses[] = $result['status'];
            }
            sort($statuses);
            $this->assertSame(2, $blocked, 'Ambas solicitudes deben competir por el bloqueo del motorista.');
            $this->assertSame([200, 422], $statuses);
            $this->assertSame(1, Order::where('courier_id', $courier->id)->count());
        } finally {
            foreach ($workers as $worker) {
                fclose($worker['pipe']);
                pcntl_waitpid($worker['pid'], $status);
            }
        }
    }
}
