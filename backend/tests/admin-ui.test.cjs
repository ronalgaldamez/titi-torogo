const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

class Element extends EventTarget {
    constructor() {
        super();
        this.dataset = {};
        this.disabled = false;
        this.textContent = '';
        this.classList = { toggle() {}, contains() { return false; } };
    }
    setAttribute(name, value) { this[name] = value; }
    removeAttribute(name) { delete this[name]; }
    focus() {}
    replaceChildren() {}
    append() {}
    querySelectorAll() { return []; }
}

function setup() {
    const document = new Element();
    document.documentElement = new Element();
    document.documentElement.dataset.adminTheme = 'original';
    document.body = new Element();
    const window = new Element();
    window.matchMedia = () => new Element();
    const ids = Object.fromEntries(['admin-theme', 'admin-confirmation', 'admin-confirm-accept', 'admin-confirm-cancel', 'admin-confirm-title', 'admin-confirm-description', 'admin-confirm-details', 'admin-submit-status'].map(id => [id, new Element()]));
    document.getElementById = id => ids[id] || null;
    document.querySelector = () => null;
    const dialog = ids['admin-confirmation'];
    dialog.showModal = () => { dialog.open = true; };
    dialog.close = () => { dialog.open = false; dialog.dispatchEvent(new Event('close')); };
    const storage = {};
    vm.runInNewContext(fs.readFileSync(__dirname + '/../public/js/admin.js', 'utf8'), {
        document, window, localStorage: { setItem(key, value) { storage[key] = value; } },
    });
    const button = new Element();
    button.textContent = 'Guardar';
    const alreadyDisabled = new Element();
    alreadyDisabled.disabled = true;
    const form = new Element();
    form.method = 'post';
    form.elements = [];
    form.querySelectorAll = () => [button, alreadyDisabled];
    let submissions = 0;
    function submit() {
        const event = new Event('submit', { cancelable: true });
        Object.defineProperties(event, { target: { value: form }, submitter: { value: button } });
        document.dispatchEvent(event);
        if (!event.defaultPrevented) submissions++;
    }
    form.requestSubmit = submit;
    return { ids, window, form, button, alreadyDisabled, submit, storage, document, submissions: () => submissions };
}

test('canceling a confirmation sends nothing; confirming and double-clicking sends once', () => {
    const ui = setup();
    ui.submit();
    assert.equal(ui.ids['admin-confirmation'].open, true);
    assert.equal(ui.submissions(), 0);
    ui.ids['admin-confirm-cancel'].dispatchEvent(new Event('click'));
    assert.equal(ui.submissions(), 0);
    ui.submit();
    ui.ids['admin-confirm-accept'].dispatchEvent(new Event('click'));
    ui.ids['admin-confirm-accept'].dispatchEvent(new Event('click'));
    ui.submit();
    assert.equal(ui.submissions(), 1);
    assert.equal(ui.button.disabled, true);
    assert.equal(ui.form['aria-busy'], 'true');
    ui.window.dispatchEvent(new Event('pageshow'));
    assert.equal(ui.button.disabled, false);
    assert.equal(ui.alreadyDisabled.disabled, true);
});

test('login skips confirmation but still blocks repeated submission', () => {
    const ui = setup();
    ui.form.dataset.skipConfirm = '';
    ui.submit();
    ui.submit();
    assert.equal(ui.submissions(), 1);
    assert.notEqual(ui.ids['admin-confirmation'].open, true);
});

test('theme choices persist and unknown values are ignored', () => {
    const ui = setup();
    ui.ids['admin-theme'].value = 'black';
    ui.ids['admin-theme'].dispatchEvent(new Event('change'));
    assert.equal(ui.document.documentElement.dataset.adminTheme, 'black');
    assert.equal(ui.storage['torogo-admin-theme'], 'black');
    ui.ids['admin-theme'].value = 'unknown';
    ui.ids['admin-theme'].dispatchEvent(new Event('change'));
    assert.equal(ui.document.documentElement.dataset.adminTheme, 'black');
});
