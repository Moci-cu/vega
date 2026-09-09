// Offline regression: runs the actual QML handlers without PAM or a session lock.
// node scripts/lock-timeout-check.cjs
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
let source = fs.readFileSync(path.join(__dirname,
    '../modules/common/panels/lock/LockContext.qml'), 'utf8');

function findCodeBrace(start) {
    let quote = null;
    for (let index = start; index < source.length; index++) {
        const character = source[index];
        if (quote) {
            if (character === '\\') index++;
            else if (character === quote) quote = null;
            continue;
        }
        if (character === '"' || character === "'" || character === '`') {
            quote = character;
            continue;
        }
        if (character === '/' && source[index + 1] === '/') {
            const newline = source.indexOf('\n', index + 2);
            if (newline < 0) break;
            index = newline;
            continue;
        }
        if (character === '/' && source[index + 1] === '*') {
            const commentEnd = source.indexOf('*/', index + 2);
            assert(commentEnd >= 0, 'unterminated block comment');
            index = commentEnd + 1;
            continue;
        }
        if (character === '{') return index;
    }
    return -1;
}

function findClosingBrace(open) {
    let quote = null;
    let depth = 1;
    for (let index = open + 1; index < source.length; index++) {
        const character = source[index];
        if (quote) {
            if (character === '\\') index++;
            else if (character === quote) quote = null;
            continue;
        }
        if (character === '"' || character === "'" || character === '`') {
            quote = character;
            continue;
        }
        if (character === '/' && source[index + 1] === '/') {
            const newline = source.indexOf('\n', index + 2);
            if (newline < 0) break;
            index = newline;
            continue;
        }
        if (character === '/' && source[index + 1] === '*') {
            const commentEnd = source.indexOf('*/', index + 2);
            assert(commentEnd >= 0, 'unterminated block comment');
            index = commentEnd + 1;
            continue;
        }
        if (character === '{') depth++;
        else if (character === '}' && --depth === 0) return index;
    }
    assert.equal(depth, 0, 'unbalanced braces');
    return -1;
}

function body(marker, start = 0, requiredMarkers = []) {
    const at = source.indexOf(marker, start);
    assert(at >= 0, marker);
    const open = findCodeBrace(at);
    assert(open >= 0, `${marker}: missing body`);
    const close = findClosingBrace(open);
    const extracted = source.slice(open + 1, close);
    for (const requiredMarker of requiredMarkers)
        assert(extracted.includes(requiredMarker), `${marker}: missing ${requiredMarker}`);
    return '(function () {' + extracted + '})()';
}
let resets = 0;
let unlocks = 0;
const timer = { running: false, restart() { this.running = true; }, stop() { this.running = false; } };
const root = {
    currentText: 'test', authenticationResolved: false, unlockInProgress: false,
    reset() { resets++; this.authenticationResolved = false; },
    clearText() { this.currentText = ''; },
    unlocked() { unlocks++; }
};
const context = vm.createContext({ root, passwordClearTimer: timer,
    GlobalStates: { screenLocked: true }, LockContext: { ActionEnum: { Unlock: 0 } } });
const expire = body('onTriggered:', source.indexOf('id: passwordClearTimer'), ['root.clearText();']);
const arm = body('function resetClearTimer()', 0, ['passwordClearTimer.restart();', 'passwordClearTimer.stop();']);
vm.runInContext(arm, context);
assert.equal(timer.running, true);
vm.runInContext(expire, context);
assert.equal(root.currentText, '');
assert.equal(resets, 0, 'Input timeout must not restart authentication');

for (const phase of ['authenticationResolved', 'unlockInProgress']) {
    root.currentText = 'test';
    root[phase] = true;
    vm.runInContext(arm, context);
    assert.equal(timer.running, false);
    vm.runInContext(expire, context); // A timeout already queued before success.
    assert.equal(root.currentText, 'test');
    assert.equal(root[phase], true);
    assert.equal(resets, 0);
    root[phase] = false;
}
root.authenticationResolved = true;
vm.runInContext(expire, context);
vm.runInContext(body('onTriggered:', source.indexOf('id: biometricSuccessTimer'), [
    'root.reset();', 'root.unlocked(LockContext.ActionEnum.Unlock);'
]), context);
assert.equal(unlocks, 1, 'Accepted biometric result must survive input expiry');
assert.equal(resets, 0);
root.authenticationResolved = false;
root.currentText = '';
vm.runInContext(arm, context);
assert.equal(timer.running, false);
console.log('PASS: idle clear, password-in-flight, biometric success/timeout race, empty input');

source = fs.readFileSync(path.join(__dirname,
    '../modules/common/panels/lock/LockScreen.qml'), 'utf8');
let delayed = 0;
const auth = { authenticationResolved: false, passwordAuthenticated: false,
    reset() { this.authenticationResolved = false; } };
const screen = { closing: false, unlockAnimationDuration: 850 };
const state = { screenLocked: true };
const lockVm = vm.createContext({ root: screen, lockContext: auth, GlobalStates: state,
    Config: { options: { lock: { security: { unlockKeyring: false } } } },
    LockContext: { ActionEnum: { Unlock: 0, Poweroff: 1, Reboot: 2 } },
    targetAction: 0, unlockAnimationTimer: { start() { delayed++; } } });
screen.finishUnlock = () => vm.runInContext(body('function finishUnlock()'), lockVm);
const accepted = body('onUnlocked:', 0, ['lockContext.authenticationResolved', 'root.finishUnlock();']);
vm.runInContext(accepted, lockVm);
screen.finishUnlock();
assert.equal(state.screenLocked, true, 'Unauthenticated signals must never unlock');
assert.equal(delayed, 0);
auth.authenticationResolved = true;
vm.runInContext(accepted, lockVm);
vm.runInContext(accepted, lockVm);
assert.equal(delayed, 1, 'Duplicate completion must not restart exit');
assert.equal(state.screenLocked, true, 'Session stays locked during exit video');
screen.finishUnlock();
assert.equal(state.screenLocked, false);
state.screenLocked = true;
screen.finishUnlock();
assert.equal(state.screenLocked, true, 'Stale exit callback must not unlock a new session');
screen.unlockAnimationDuration = 0;
auth.authenticationResolved = true;
vm.runInContext(accepted, lockVm);
assert.equal(state.screenLocked, false, 'Vega retains immediate unlock');
console.log('PASS: Unit-4 authenticated exit gate, duplicate/stale callbacks, Vega immediate unlock');
