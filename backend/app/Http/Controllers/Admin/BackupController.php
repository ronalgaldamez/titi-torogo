<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\BackupSettingsRequest;
use App\Models\Backup;
use App\Models\BackupSetting;
use App\Support\BackupService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class BackupController extends Controller
{
    public function index(): View
    {
        return view('admin.backups.index', [
            'settings' => BackupSetting::current(), 'configured' => BackupService::configured(),
            'backups' => Backup::latest('id')->paginate(20),
            'lastSuccess' => Backup::where('status', 'succeeded')->latest('id')->first(),
            'active' => Backup::whereIn('status', ['pending', 'running'])->exists(),
        ]);
    }

    public function store(BackupService $service): RedirectResponse
    {
        $this->requireConfiguration();
        $backup = $service->request('manual');

        return redirect()->route('admin.backups.index')->with(
            $backup === null ? 'error' : 'status',
            $backup === null ? 'Ya hay un respaldo en espera o en ejecución.'
                : 'Respaldo solicitado. El servidor lo iniciará en el próximo minuto, aunque cierres el panel.',
        );
    }

    public function update(BackupSettingsRequest $request): RedirectResponse
    {
        if ($request->boolean('enabled')) {
            $this->requireConfiguration();
        }
        BackupSetting::current();
        DB::transaction(function () use ($request) {
            $settings = BackupSetting::query()->lockForUpdate()->findOrFail(1);
            $settings->enabled = $request->boolean('enabled');
            $settings->time = $request->validated('time');
            $settings->save();
        });

        return redirect()->route('admin.backups.index')->with('status', 'Programación actualizada en hora de El Salvador.');
    }

    public function download(Backup $backup): StreamedResponse
    {
        abort_unless($backup->status === 'succeeded' && $backup->path !== null
            && $backup->finished_at->gt(now()->subDays(30)), 404);

        return Storage::disk('backups')->download($backup->path, 'torogo-backup-'.$backup->id.'.tar.gz', [
            'Cache-Control' => 'private, no-store',
        ]);
    }

    private function requireConfiguration(): void
    {
        if (! BackupService::configured()) {
            throw ValidationException::withMessages(['backup' => 'Falta configurar las credenciales y el bucket exclusivo de respaldos en el servidor.']);
        }
    }
}
