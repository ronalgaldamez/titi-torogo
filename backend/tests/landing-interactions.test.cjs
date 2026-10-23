const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');

test('Los pasos actualizan el ejemplo como texto y conservan el contacto', () => {
    const label = {};
    const copy = {};
    const steps = [0, 1, 2].map(index => ({
        dataset: { stepLabel: `Paso ${index}`, stepExample: `<b>Ejemplo ${index}</b>` },
        setAttribute(name, value) { this[name] = value; },
        addEventListener(event, callback) { this.click = callback; },
    }));
    const example = { querySelector: selector => selector === 'small' ? label : copy };
    const title = {};
    const description = {};
    const dialog = {
        querySelector: selector => selector === '.tl-dialog-title' ? title : description,
        showModal() { this.open = true; },
    };
    const interest = {
        addEventListener(event, callback) { this.click = callback; },
        closest: () => ({ querySelector: selector => ({ textContent: selector === 'h3' ? 'Negocio' : 'Descripción' }) }),
    };
    const root = {
        querySelectorAll: selector => selector === '.tl-step-trigger' ? steps : [interest],
        querySelector: selector => selector === '.tl-step-example' ? example : dialog,
    };
    runInNewContext(readFileSync(__dirname + '/../public/js/landing.js', 'utf8'), {
        document: { getElementById: () => root, addEventListener: (event, callback) => callback() },
    });
    steps[2].click();
    assert.equal(steps[2]['aria-pressed'], 'true');
    assert.equal(steps[0]['aria-pressed'], 'false');
    assert.equal(copy.textContent, '<b>Ejemplo 2</b>');
    steps[1].click();
    assert.equal(label.textContent, 'Paso 1');
    assert.equal(steps[2]['aria-pressed'], 'false');
    interest.click();
    assert.equal(dialog.open, true);
    assert.equal(title.textContent, 'Negocio');
});

test('Los enlaces abren solo diálogos dentro de la landing', () => {
    const dialog = { showModal() { this.open = true; } };
    const external = { showModal() { throw new Error('Diálogo fuera de la landing'); } };
    const buttons = ['legal', 'external', 'missing'].map(id => ({
        dataset: { landingDialog: id },
        addEventListener(event, callback) { this.click = callback; },
    }));
    const root = {
        querySelectorAll: selector => selector === '[data-landing-dialog]' ? buttons : [],
        querySelector: () => null,
        contains: target => target === dialog,
    };
    runInNewContext(readFileSync(__dirname + '/../public/js/landing.js', 'utf8'), {
        document: {
            getElementById: id => ({ 'tl-torogo': root, legal: dialog, external })[id],
            addEventListener: (event, callback) => callback(),
        },
    });
    buttons[0].click();
    assert.equal(dialog.open, true);
    buttons[1].click();
    buttons[2].click();
});
