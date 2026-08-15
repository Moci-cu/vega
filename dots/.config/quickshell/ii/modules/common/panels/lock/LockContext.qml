import qs
import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    enum ActionEnum { Unlock, Poweroff, Reboot }

    signal shouldReFocus()
    signal unlocked(targetAction: var)
    signal failed()

    // These properties are in the context and not individual lock surfaces
    // so all surfaces can share the same state.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool authenticationResolved: false
    property bool passwordAuthenticated: false
    property bool showFailure: false
    property bool fingerprintsConfigured: false
    readonly property int fingerprintUnavailable: 0
    readonly property int fingerprintReady: 1
    readonly property int fingerprintScanning: 2
    readonly property int fingerprintRetryPending: 3
    readonly property int fingerprintFailed: 4
    readonly property int fingerprintSuccess: 5
    property int fingerprintState: root.fingerprintUnavailable
    property int fingerprintRetryCount: 0
    readonly property int maxFingerprintRetries: 2
    readonly property string fingerprintUsername: Quickshell.env("USER") ?? SystemInfo.username
    readonly property string fingerprintStatusText: {
        switch (root.fingerprintState) {
        case root.fingerprintReady:
            return Translation.tr("Fingerprint ready");
        case root.fingerprintScanning:
            return Translation.tr("Touch the fingerprint sensor");
        case root.fingerprintRetryPending:
            return Translation.tr("Retrying fingerprint scan...");
        case root.fingerprintFailed:
            return Translation.tr("Fingerprint failed. Click to retry");
        case root.fingerprintSuccess:
            return Translation.tr("Fingerprint recognized");
        default:
            return "";
        }
    }
    property bool faceAvailable: false
    readonly property bool faceUnlockEnabled: Config.ready && Config.options.lock.security.faceUnlock
    readonly property int faceUnavailable: 0
    readonly property int faceReady: 1
    readonly property int faceWaiting: 2
    readonly property int faceScanning: 3
    readonly property int faceFailed: 4
    readonly property int faceSuccess: 5
    property int faceState: root.faceUnavailable
    readonly property string faceStatusText: {
        switch (root.faceState) {
        case root.faceReady:
            return Translation.tr("Face unlock ready");
        case root.faceWaiting:
            return Translation.tr("Face scan starts shortly");
        case root.faceScanning:
            return Translation.tr("Looking for your face");
        case root.faceFailed:
            return Translation.tr("Face unlock failed. Click to retry");
        case root.faceSuccess:
            return Translation.tr("Face recognized");
        default:
            return "";
        }
    }
    property var targetAction: LockContext.ActionEnum.Unlock
    property bool alsoInhibitIdle: false
    property bool fingerprintSessionAllowed: false
    property bool faceSessionAllowed: false

    function resetTargetAction() {
        root.targetAction = LockContext.ActionEnum.Unlock;
    }

    function clearText() {
        root.currentText = "";
    }

    function resetClearTimer() {
        passwordClearTimer.restart();
    }

    function reset() {
        biometricSuccessTimer.stop();
        stopFingerPam();
        stopFacePam();
        root.resetTargetAction();
        root.clearText();
        root.unlockInProgress = false;
        root.authenticationResolved = false;
        root.passwordAuthenticated = false;
        root.fingerprintRetryCount = 0;
        if (GlobalStates.screenLocked) {
            root.tryFingerUnlock();
            root.scheduleFaceUnlock();
        }
    }

    Timer {
        id: passwordClearTimer
        interval: 10000
        onTriggered: {
            root.reset();
        }
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            showFailure = false;
            GlobalStates.screenUnlockFailed = false;
        }
        GlobalStates.screenLockContainsCharacters = currentText.length > 0;
        passwordClearTimer.restart();
    }

    function tryUnlock(alsoInhibitIdle = false) {
        if (root.authenticationResolved) return;
        root.alsoInhibitIdle = alsoInhibitIdle;
        root.unlockInProgress = true;
        root.passwordAuthenticated = false;
        pam.start();
    }

    function tryFingerUnlock() {
        if (!root.fingerprintsConfigured
                || !GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved
                || fingerPam.active)
            return;

        fingerprintRetryTimer.stop();
        root.fingerprintSessionAllowed = true;
        root.fingerprintState = root.fingerprintScanning;
        if (!fingerPam.start() && root.fingerprintState === root.fingerprintScanning)
            scheduleFingerprintRetry();
    }

    function retryFingerUnlock() {
        if (!root.fingerprintsConfigured
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved
                || fingerPam.active)
            return;

        root.fingerprintRetryCount = 0;
        tryFingerUnlock();
    }

    function scheduleFingerprintRetry() {
        if (!root.fingerprintSessionAllowed
                || !GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock)
            return;

        if (root.fingerprintRetryCount >= root.maxFingerprintRetries) {
            root.fingerprintSessionAllowed = false;
            root.fingerprintState = root.fingerprintFailed;
            return;
        }

        root.fingerprintRetryCount++;
        root.fingerprintState = root.fingerprintRetryPending;
        fingerprintRetryTimer.restart();
    }

    function refreshFingerprintAvailability() {
        if (root.fingerprintsConfigured) return;
        if (!fingerprintCheckProc.running) fingerprintCheckProc.running = true;
    }

    function scheduleFaceUnlock() {
        if (!root.faceUnlockEnabled
                || !root.faceAvailable
                || !GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved)
            return;

        root.faceSessionAllowed = true;
        root.faceState = root.faceWaiting;
        faceStartTimer.restart();
    }

    function tryFaceUnlock() {
        if (!root.faceUnlockEnabled
                || !root.faceAvailable
                || !GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved
                || facePam.active)
            return;

        faceStartTimer.stop();
        root.faceSessionAllowed = true;
        root.faceState = root.faceScanning;
        faceScanTimeoutTimer.restart();
        if (!facePam.start()) {
            faceScanTimeoutTimer.stop();
            root.faceSessionAllowed = false;
            root.faceState = root.faceFailed;
        }
    }

    function retryFaceUnlock() {
        if (!root.faceUnlockEnabled
                || !root.faceAvailable
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved
                || facePam.active)
            return;

        tryFaceUnlock();
    }

    function refreshFaceAvailability() {
        if (root.faceAvailable) return;
        if (!faceCheckProc.running) faceCheckProc.running = true;
    }

    function stopFingerPam() {
        root.fingerprintSessionAllowed = false;
        fingerprintRetryTimer.stop();
        if (fingerPam.active) fingerPam.abort();
        root.fingerprintState = root.fingerprintsConfigured
            ? root.fingerprintReady
            : root.fingerprintUnavailable;
    }

    function stopFacePam() {
        root.faceSessionAllowed = false;
        faceStartTimer.stop();
        faceScanTimeoutTimer.stop();
        if (facePam.active) facePam.abort();
        root.faceState = root.faceAvailable
            ? root.faceReady
            : root.faceUnavailable;
    }

    function completeBiometricUnlock(method) {
        if (root.authenticationResolved
                || !GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock)
            return;

        root.authenticationResolved = true;
        root.passwordAuthenticated = false;
        root.unlockInProgress = true;
        root.fingerprintSessionAllowed = false;
        root.faceSessionAllowed = false;
        fingerprintRetryTimer.stop();
        faceStartTimer.stop();
        faceScanTimeoutTimer.stop();

        if (method === "fingerprint") {
            root.fingerprintState = root.fingerprintSuccess;
            root.faceState = root.faceAvailable ? root.faceReady : root.faceUnavailable;
            if (facePam.active) facePam.abort();
        } else {
            root.faceState = root.faceSuccess;
            root.fingerprintState = root.fingerprintsConfigured
                ? root.fingerprintReady
                : root.fingerprintUnavailable;
            if (fingerPam.active) fingerPam.abort();
        }

        if (pam.active) pam.abort();
        biometricSuccessTimer.restart();
    }

    onTargetActionChanged: {
        if (root.targetAction !== LockContext.ActionEnum.Unlock) {
            stopFingerPam();
            stopFacePam();
        } else if (GlobalStates.screenLocked) {
            if (root.fingerprintsConfigured) {
                root.fingerprintRetryCount = 0;
                fingerprintRetryTimer.restart();
            }
            scheduleFaceUnlock();
        }
    }

    onFaceUnlockEnabledChanged: {
        if (!root.faceUnlockEnabled) {
            stopFacePam();
        } else if (GlobalStates.screenLocked) {
            scheduleFaceUnlock();
        }
    }

    Timer {
        id: fingerprintRetryTimer
        interval: 750
        onTriggered: root.tryFingerUnlock()
    }

    Timer {
        id: faceStartTimer
        interval: Math.max(0, Config.options.lock.security.faceUnlockDelayMs)
        onTriggered: root.tryFaceUnlock()
    }

    Timer {
        id: faceScanTimeoutTimer
        interval: 10000
        onTriggered: {
            root.faceSessionAllowed = false;
            if (facePam.active) facePam.abort();
            if (!root.authenticationResolved)
                root.faceState = root.faceFailed;
        }
    }

    Timer {
        id: biometricSuccessTimer
        interval: 450
        onTriggered: {
            if (!GlobalStates.screenLocked) {
                root.reset();
                return;
            }
            root.unlocked(LockContext.ActionEnum.Unlock);
        }
    }

    Process {
        id: fingerprintCheckProc
        running: true
        command: ["fprintd-list", root.fingerprintUsername]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            id: fingerprintOutputCollector
            onStreamFinished: {
                root.fingerprintsConfigured = fingerprintOutputCollector.text.includes("Fingerprints for user");
                if (root.fingerprintState === root.fingerprintSuccess) return;

                if (!root.fingerprintsConfigured) {
                    root.stopFingerPam();
                } else if (fingerPam.active) {
                    root.fingerprintState = root.fingerprintScanning;
                } else {
                    root.fingerprintState = root.fingerprintReady;
                }
                if (root.fingerprintsConfigured && GlobalStates.screenLocked && !fingerPam.active)
                    root.tryFingerUnlock();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.fingerprintState !== root.fingerprintSuccess) {
                // console.warn("[LockContext] fprintd-list command exited with error:", exitCode, exitStatus);
                root.fingerprintsConfigured = false;
                root.stopFingerPam();
            }
        }
    }

    Process {
        id: faceCheckProc
        running: true
        command: ["test", "-r", "/usr/lib/security/pam_gaze.so"]
        onExited: (exitCode, exitStatus) => {
            root.faceAvailable = exitCode === 0;
            if (!root.faceAvailable) {
                root.stopFacePam();
            } else if (root.faceState !== root.faceSuccess) {
                root.faceState = root.faceReady;
                if (GlobalStates.screenLocked)
                    root.scheduleFaceUnlock();
            }
        }
    }

    PamContext {
        id: pam

        // pam_unix will ask for a response for the password prompt
        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        // pam_unix won't send any important messages so all we need is the completion status.
        onCompleted: result => {
            if (root.authenticationResolved) return;

            if (result == PamResult.Success) {
                root.authenticationResolved = true;
                root.passwordAuthenticated = true;
                stopFacePam();
                root.unlocked(root.targetAction);
                stopFingerPam();
            } else {
                root.clearText();
                root.unlockInProgress = false;
                GlobalStates.screenUnlockFailed = true;
                root.showFailure = true;
            }
        }
    }

    PamContext {
        id: fingerPam

        configDirectory: "pam"
        config: "fprintd.conf"

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.completeBiometricUnlock("fingerprint");
            } else if (!root.fingerprintSessionAllowed) {
                return;
            } else if (result == PamResult.MaxTries) {
                root.fingerprintSessionAllowed = false;
                root.fingerprintState = root.fingerprintFailed;
            } else {
                root.scheduleFingerprintRetry();
            }
        }
    }

    PamContext {
        id: facePam

        configDirectory: "pam"
        config: "gaze.conf"

        onCompleted: result => {
            faceScanTimeoutTimer.stop();
            if (result == PamResult.Success) {
                root.completeBiometricUnlock("face");
            } else if (root.faceSessionAllowed && !root.authenticationResolved) {
                root.faceSessionAllowed = false;
                root.faceState = root.faceFailed;
            }
        }
    }
}
