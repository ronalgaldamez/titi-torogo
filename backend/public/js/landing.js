document.addEventListener('DOMContentLoaded', () => {
    const root = document.getElementById('tl-torogo');
    if (!root) return;
    root.querySelectorAll('[data-landing-dialog]').forEach(button => {
        button.addEventListener('click', () => {
            const target = document.getElementById(button.dataset.landingDialog);
            if (target && root.contains(target)) target.showModal();
        });
    });
    const steps = root.querySelectorAll('.tl-step-trigger');
    const example = root.querySelector('.tl-step-example');
    if (example) {
        steps.forEach(button => button.addEventListener('click', () => {
            steps.forEach(step => step.setAttribute('aria-pressed', String(step === button)));
            example.querySelector('small').textContent = button.dataset.stepLabel;
            example.querySelector('strong').textContent = button.dataset.stepExample;
        }));
    }
    const dialog = root?.querySelector('.tl-contact-dialog');
    if (!dialog) return;
    root.querySelectorAll('.tl-interest').forEach(button => {
        button.addEventListener('click', () => {
            const section = button.closest('article');
            dialog.querySelector('.tl-dialog-title').textContent = section.querySelector('h3').textContent;
            dialog.querySelector('.tl-dialog-copy').textContent = section.querySelector('p').textContent;
            dialog.showModal();
        });
    });
});
