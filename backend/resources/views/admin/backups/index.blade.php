@extends('layouts.panel')
@section('title', 'Respaldos')
@section('content')
    <h1 class="text-2xl font-extrabold">Respaldos</h1>
    <p class="mt-2 text-sm text-navy/70">Copias privadas de PostgreSQL y de las imágenes locales de la página web y categorías.</p>
    <p class="mt-2 text-sm text-navy/70">Las imágenes de restaurantes que ya están en S3 y los secretos del servidor necesitan protección aparte.</p>

    @if ($errors->any())
        <div role="alert" class="mt-5 rounded-2xl bg-coral/15 p-5">{{ $errors->first() }}</div>
    @endif
    @unless ($configured)
        <div role="alert" class="mt-5 rounded-2xl bg-coral/15 p-5">Falta conectar el bucket exclusivo de respaldos. Las credenciales se configuran únicamente en el servidor.</div>
    @endunless

    <section class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 class="text-lg font-bold">Última copia correcta</h2>
        <p class="mt-2">{{ $lastSuccess?->finished_at?->timezone('America/El_Salvador')->format('d/m/Y h:i a') ?? 'Todavía no hay una copia correcta.' }}</p>
        <p class="mt-2 text-sm text-navy/70">Una copia correcta confirma la subida y su integridad. La recuperación debe comprobarse en un entorno aislado.</p>
        <form method="POST" action="{{ route('admin.backups.store') }}" class="mt-4" data-confirm-title="¿Crear un respaldo ahora?" data-confirm="Se generará una copia privada de la base de datos y las imágenes locales en el bucket de respaldos.">
            @csrf
            <button @disabled(!$configured || $active) class="rounded-full bg-navy px-5 py-3 font-semibold text-white disabled:opacity-50">Respaldar ahora</button>
        </form>
        @if ($active)
            <p role="status" class="mt-3 text-sm">Hay una copia en espera o en ejecución. <a class="underline" href="{{ route('admin.backups.index') }}">Actualizar historial</a></p>
        @endif
    </section>

    <section class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 class="text-lg font-bold">Programación diaria</h2>
        <form method="POST" action="{{ route('admin.backups.update') }}" class="mt-4 flex flex-wrap items-end gap-5" data-confirm-title="¿Guardar la programación?" data-confirm="Se actualizarán la activación y la hora diaria de los respaldos automáticos del servidor.">
            @csrf @method('PUT')
            <input type="hidden" name="enabled" value="0">
            <label class="flex items-center gap-2"><input type="checkbox" name="enabled" value="1" @checked(old('enabled', $settings->enabled))> Activar respaldos automáticos</label>
            <label>Hora de El Salvador
                <input type="time" name="time" required value="{{ old('time', $settings->time) }}" class="ml-2 rounded-xl border border-navy/20 px-3 py-2">
            </label>
            <button class="rounded-full bg-navy px-5 py-3 font-semibold text-white">Guardar programación</button>
        </form>
        <p class="mt-3 text-sm text-navy/70">El servidor ejecuta las copias aunque no estés conectado. Si estuvo apagado a la hora elegida, hace la copia al volver ese día.</p>
        <p class="mt-2 text-sm text-navy/70">Conservación acordada: 30 días. La eliminación de objetos y versiones antiguas se configura en el ciclo de vida de S3.</p>
    </section>

    <section class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 class="text-lg font-bold">Historial</h2>
        <a class="mt-2 inline-block text-sm underline" href="{{ route('admin.backups.index') }}">Actualizar historial</a>
        <div class="mt-4 overflow-x-auto">
            <table class="w-full text-left text-sm">
                <thead><tr><th class="p-2">Fecha · El Salvador</th><th class="p-2">Origen</th><th class="p-2">Estado</th><th class="p-2">Tamaño</th><th class="p-2">Archivo</th></tr></thead>
                <tbody>
                @forelse ($backups as $backup)
                    <tr class="border-t border-navy/10">
                        <td class="p-2">{{ $backup->created_at->timezone('America/El_Salvador')->format('d/m/Y h:i a') }}</td>
                        <td class="p-2">{{ $backup->source === 'scheduled' ? 'Automático' : 'Manual' }}</td>
                        <td class="p-2">
                            {{ ['pending' => 'En espera', 'running' => 'En ejecución', 'succeeded' => 'Correcto', 'failed' => 'Falló'][$backup->status] }}
                            @if ($backup->error)<p role="alert" class="mt-1 text-coral">{{ $backup->error }}</p>@endif
                        </td>
                        <td class="p-2">{{ $backup->bytes === null ? '—' : number_format($backup->bytes / 1024 / 1024, 2).' MB' }}</td>
                        <td class="p-2">
                            @if ($backup->status === 'succeeded' && $backup->finished_at->gt(now()->subDays(30)))
                                <a class="underline" href="{{ route('admin.backups.download', $backup) }}">Descargar copia privada</a>
                                <details class="mt-2"><summary>Ver SHA-256</summary><code class="break-all">{{ $backup->sha256 }}</code></details>
                            @elseif ($backup->status === 'succeeded')
                                Fuera de retención
                            @else
                                —
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="p-3">Todavía no se han solicitado respaldos.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
        <div class="mt-4">{{ $backups->links() }}</div>
    </section>
@endsection
