<?php

namespace App\Console\Commands;

use App\Support\BackupService;
use Illuminate\Console\Command;

class RunBackups extends Command
{
    protected $signature = 'backups:run';

    protected $description = 'Procesar un respaldo pendiente y comprobar la programación diaria';

    public function handle(BackupService $service): int
    {
        return $service->run() ? self::SUCCESS : self::FAILURE;
    }
}
