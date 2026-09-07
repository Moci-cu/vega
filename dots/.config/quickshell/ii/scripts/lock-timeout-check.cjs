// Offline regression: runs the actual QML handlers without PAM or a session lock.
// node scripts/lock-timeout-check.cjs
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
let source = fs.readFileSync(path.join(__dirname,
    '../modules/common/panels/lock/LockContext.qml'), 'utf8');

function body(marker, start = 0) {
    const at = source.indexOf(marker, start);
    assert(at >= 0, marker);
    const open = source.indexOf('{', at);
    let depth = 1;
    let end = open + 1;
    while (depth && end < source.length) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
        end++;
    }
    assert.equal(depth, 0);
    return '(function () {' + source.slice(open + 1, end - 1) + '})()';
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
const expire = body('onTriggered:', source.indexOf('id: passwordClearTimer'));
const arm = body('function resetClearTimer()');
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
vm.runInContext(body('onTriggered:', source.indexOf('id: biometricSuccessTimer')), context);
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
const accepted = body('onUnlocked:');
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
