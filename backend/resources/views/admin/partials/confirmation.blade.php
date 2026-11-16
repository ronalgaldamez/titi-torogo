<dialog id="admin-confirmation" class="admin-confirmation" aria-labelledby="admin-confirm-title" aria-describedby="admin-confirm-description">
    <span class="admin-dialog-mark">@include('admin.partials.icon', ['icon' => 'shield'])</span>
    <span class="admin-overline">CONFIRMAR ACCIÓN</span>
    <h2 id="admin-confirm-title">¿Confirmás este cambio?</h2>
    <p id="admin-confirm-description"></p>
    <dl id="admin-confirm-details"></dl>
    <div class="admin-dialog-actions"><button type="button" class="admin-button admin-button-secondary" id="admin-confirm-cancel">Volver</button><button type="button" class="admin-button" id="admin-confirm-accept">Confirmar</button></div>
</dialog>
<p id="admin-submit-status" class="admin-submit-status" role="status" aria-live="polite" hidden>Procesando. Esperá un momento…</p>
