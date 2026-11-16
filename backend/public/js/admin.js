(() => {
    'use strict';
    const root = document.documentElement;
    const appearance = document.getElementById('admin-theme');
    if (appearance) {
        appearance.value = root.dataset.adminTheme;
        appearance.addEventListener('change', () => {
            if (!['original', 'black', 'white'].includes(appearance.value)) return;
            root.dataset.adminTheme = appearance.value;
            try { localStorage.setItem('torogo-admin-theme', appearance.value); } catch {}
        });
    }

    const menu = document.getElementById('admin-sidebar');
    const openMenu = document.getElementById('admin-menu-open');
    const shade = document.querySelector('.admin-menu-shade');
    function setMenu(open) {
        document.body.classList.toggle('admin-menu-visible', open);
        openMenu?.setAttribute('aria-expanded', String(open));
        if (shade) shade.hidden = !open;
        const workspace = document.querySelector('.admin-workspace');
        if (workspace) workspace.inert = open;
        if (open) menu.querySelector('a')?.focus();
        else openMenu?.focus();
    }
    openMenu?.addEventListener('click', () => setMenu(true));
    document.querySelectorAll('[data-menu-close]').forEach(button => button.addEventListener('click', () => setMenu(false)));
    document.addEventListener('keydown', event => {
        if (!document.body.classList.contains('admin-menu-visible')) return;
        if (event.key === 'Escape') { setMenu(false); return; }
        if (event.key !== 'Tab') return;
        const focusable = [...menu.querySelectorAll('a, button')].filter(element => element.getClientRects().length);
        const first = focusable[0], last = focusable.at(-1);
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    });
    // El menú deja de ser modal al volver al ancho de escritorio.
    const narrow = window.matchMedia('(max-width: 900px)');
    narrow.addEventListener('change', () => { if (!narrow.matches && document.body.classList.contains('admin-menu-visible')) setMenu(false); });

    document.getElementById('admin-show-password')?.addEventListener('click', event => {
        const input = document.getElementById('password');
        input.type = input.type === 'password' ? 'text' : 'password';
        event.currentTarget.textContent = input.type === 'password' ? 'Mostrar' : 'Ocultar';
        event.currentTarget.setAttribute('aria-pressed', String(input.type === 'text'));
    });

    // Las mismas tablas se leen como fichas en móvil, conservando todos sus datos.
    document.querySelectorAll('.admin-content table').forEach(table => {
        const headers = [...table.querySelectorAll('thead th')].map(header => header.textContent.trim());
        if (!headers.length) return;
        table.classList.add('admin-mobile-table');
        table.querySelectorAll('tbody tr').forEach(row => [...row.cells].forEach((cell, i) => {
            if (cell.colSpan !== 1) return;
            cell.dataset.label = headers[i] || 'Acciones';
            const value = document.createElement('div');
            value.className = 'admin-cell-value';
            value.append(...cell.childNodes);
            cell.append(value);
        }));
    });
    document.querySelectorAll('.admin-content form[method="GET"], .admin-content form[method="get"]').forEach(form => form.classList.add('admin-filter-form'));

    const dialog = document.getElementById('admin-confirmation');
    const accept = document.getElementById('admin-confirm-accept');
    const cancel = document.getElementById('admin-confirm-cancel');
    const status = document.getElementById('admin-submit-status');
    let pending = null;
    const approved = new WeakSet();
    const sending = new Set();
    const disabledButtons = new Set();
    const confirmDetails = ['courier_id', 'courier_fee', 'platform_fee', 'time', 'enabled'];

    function showConfirmation(form, submitter) {
        pending = { form, submitter };
        document.getElementById('admin-confirm-title').textContent = form.dataset.confirmTitle || '¿Confirmás esta acción?';
        document.getElementById('admin-confirm-description').textContent = form.dataset.confirm || 'Se guardarán los cambios de este formulario. Revisá los datos antes de continuar.';
        accept.textContent = submitter?.textContent.trim() || 'Confirmar';
        accept.classList.toggle('admin-button-danger', form.dataset.confirmDanger === 'true');
        const details = document.getElementById('admin-confirm-details');
        details.replaceChildren();
        [...form.elements].filter(field => confirmDetails.includes(field.name) && field.type !== 'hidden').forEach(field => {
            const row = document.createElement('div');
            const label = document.createElement('dt');
            const value = document.createElement('dd');
            label.textContent = ({courier_id:'Motorizado', courier_fee:'Para el motorizado', platform_fee:'Servicio ToroGo', time:'Hora de El Salvador', enabled:'Automáticos'})[field.name];
            value.textContent = field.tagName === 'SELECT' ? field.selectedOptions[0]?.textContent.trim() : field.type === 'checkbox' ? (field.checked ? 'Activados' : 'Desactivados') : field.value;
            if (['courier_fee', 'platform_fee'].includes(field.name)) value.textContent = '$' + field.value;
            row.append(label, value);
            details.append(row);
        });
        dialog.showModal();
        cancel.focus();
    }

    document.addEventListener('submit', event => {
        const form = event.target;
        if (form.method.toLowerCase() === 'get') return;
        if (sending.has(form) || (pending && pending.form !== form)) { event.preventDefault(); return; }
        if (dialog && form.dataset.skipConfirm === undefined && !approved.has(form)) {
            event.preventDefault();
            if (!pending) showConfirmation(form, event.submitter);
            return;
        }
        approved.delete(form);
        sending.add(form);
        form.setAttribute('aria-busy', 'true');
        // Se bloquean botones, no campos: los valores y archivos deben enviarse intactos.
        form.querySelectorAll('button, input[type=submit]').forEach(button => {
            if (button.disabled) return;
            button.disabled = true;
            disabledButtons.add(button);
        });
        if (status) status.hidden = false;
    });
    cancel?.addEventListener('click', () => dialog.close());
    dialog?.addEventListener('close', () => {
        const submitter = pending?.submitter;
        pending = null;
        submitter?.focus();
    });
    accept?.addEventListener('click', () => {
        if (!pending || accept.disabled) return;
        const { form, submitter } = pending;
        pending = null;
        approved.add(form);
        accept.disabled = true;
        dialog.close();
        try { form.requestSubmit(submitter || undefined); }
        finally { approved.delete(form); accept.disabled = false; }
    });
    // Al regresar con Atrás, el navegador puede recuperar botones bloqueados de su caché.
    window.addEventListener('pageshow', () => {
        for (const form of sending) form.removeAttribute('aria-busy');
        sending.clear();
        for (const button of disabledButtons) button.disabled = false;
        disabledButtons.clear();
        if (status) status.hidden = true;
    });
})();
