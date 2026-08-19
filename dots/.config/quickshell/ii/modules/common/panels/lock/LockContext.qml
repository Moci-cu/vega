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
    signal faceFallbackStarted()
    signal faceFallbackCompleted()

    // These properties are in the context and not individual lock surfaces
    // so all surfaces can share the same state.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool authenticationResolved: false
    property bool passwordAuthenticated: false
    property bool showFailure: false
    property bool fingerprintsConfigured: false
    readonly property bool fingerprintUnlockEnabled: Config.ready
        && Config.options.lock.security.fingerprintUnlock
    readonly property int fingerprintUnavailable: 0
    readonly property int fingerprintReady: 1
    readonly property int fingerprintScanning: 2
    readonly property int fingerprintRetryPending: 3
    readonly property int fingerprintFailed: 4
    readonly property int fingerprintSuccess: 5
    property int fingerprintState: root.fingerprintUnavailable
    property int fingerprintRetryCount: 0
    readonly property int maxFingerprintRetries: 2
    readonly property string fingerprintUsername: Quickshell.env("USER") || SystemInfo.username
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
    property bool faceFallbackPending: false
    property bool fingerprintResumePending: false
    property bool faceResumePending: false
    property double biometricResumeStartedAt: 0
    readonly property int faceFallbackAnimationMs: 480

    function resetTargetAction() {
        root.targetAction = LockContext.ActionEnum.Unlock;
    }

    function clearText() {
        root.currentText = "";
    }

    function resetClearTimer() {
        passwordClearTimer.restart();
    }

    function biometricResultName(result) {
        if (result === PamResult.Success) return "success";
        if (result === PamResult.MaxTries) return "max-tries";
        return "failed";
    }

    function logBiometric(message) {
        console.info("[Biometric]", message);
    }

    function reset() {
        biometricSuccessTimer.stop();
        cancelBiometricResume();
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

    function resumeBiometricUnlock() {
        if (!GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved)
            return;

        root.cancelBiometricResume();
        stopFingerPam();
        stopFacePam();
        root.fingerprintRetryCount = 0;
        root.refreshFingerprintAvailability();
        root.refreshFaceAvailability();
        root.biometricResumeStartedAt = Date.now();
        root.fingerprintResumePending = root.fingerprintUnlockEnabled
            && root.fingerprintsConfigured;
        root.faceResumePending = root.faceUnlockEnabled && root.faceAvailable;
        root.logBiometric("Wake rearm requested");
        if (root.fingerprintResumePending || root.faceResumePending)
            biometricResumeTimer.start();
        else
            root.biometricResumeStartedAt = 0;
    }

    function cancelBiometricResume() {
        biometricResumeTimer.stop();
        root.fingerprintResumePending = false;
        root.faceResumePending = false;
        root.biometricResumeStartedAt = 0;
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
        if (!root.fingerprintUnlockEnabled
                || !root.fingerprintsConfigured
                || !GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved
                || fingerPam.active)
            return false;

        fingerprintRetryTimer.stop();
        root.fingerprintSessionAllowed = true;
        root.fingerprintState = root.fingerprintScanning;
        const started = fingerPam.start();
        if (!started && root.fingerprintState === root.fingerprintScanning)
            scheduleFingerprintRetry();
        return started;
    }

    function retryFingerUnlock() {
        if (!root.fingerprintUnlockEnabled
                || !root.fingerprintsConfigured
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved
                || fingerPam.active)
            return;

        root.fingerprintRetryCount = 0;
        tryFingerUnlock();
    }

    function scheduleFingerprintRetry() {
        if (!root.fingerprintUnlockEnabled
                || !root.fingerprintSessionAllowed
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

        root.faceState = root.faceWaiting;
        root.faceFallbackPending = false;
        faceFallbackTimer.stop();
        root.faceSessionAllowed = true;
        faceStartTimer.restart();
    }

    function canFallbackToFingerprint() {
        return root.fingerprintUnlockEnabled
            && root.fingerprintsConfigured
            && GlobalStates.screenLocked
            && root.targetAction === LockContext.ActionEnum.Unlock
            && !root.authenticationResolved;
    }

    function failFaceUnlock() {
        faceScanTimeoutTimer.stop();
        root.logBiometric("Face scan failed");
        root.faceSessionAllowed = false;
        const fallbackAvailable = root.canFallbackToFingerprint();

        if (!fallbackAvailable) {
            root.faceFallbackPending = false;
            faceFallbackTimer.stop();
            root.faceState = root.faceFailed;
            return;
        }

        const startingFallback = !root.faceFallbackPending;
        root.faceFallbackPending = true;
        root.faceState = root.faceFailed;
        if (startingFallback) root.faceFallbackStarted();
        faceFallbackTimer.restart();
    }

    function tryFaceUnlock() {
        if (!root.faceUnlockEnabled
                || !root.faceAvailable
                || !GlobalStates.screenLocked
                || root.targetAction !== LockContext.ActionEnum.Unlock
                || root.authenticationResolved
                || facePam.active)
            return false;

        faceStartTimer.stop();
        root.faceState = root.faceScanning;
        root.faceFallbackPending = false;
        faceFallbackTimer.stop();
        root.faceSessionAllowed = true;
        faceScanTimeoutTimer.restart();
        const started = facePam.start();
        if (!started) root.failFaceUnlock();
        return started;
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
        root.faceFallbackPending = false;
        faceStartTimer.stop();
        faceScanTimeoutTimer.stop();
        faceFallbackTimer.stop();
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
        root.cancelBiometricResume();
        faceStartTimer.stop();
        faceScanTimeoutTimer.stop();
        faceFallbackTimer.stop();
        root.faceFallbackPending = false;

        if (method === "fingerprint") {
            root.logBiometric("Fingerprint unlock accepted");
            root.fingerprintState = root.fingerprintSuccess;
            root.faceState = root.faceAvailable ? root.faceReady : root.faceUnavailable;
            if (facePam.active) facePam.abort();
        } else {
            root.logBiometric("Face unlock accepted");
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
            if (root.fingerprintUnlockEnabled && root.fingerprintsConfigured) {
                root.fingerprintRetryCount = 0;
                fingerprintRetryTimer.restart();
            }
            scheduleFaceUnlock();
        }
    }

    onFingerprintUnlockEnabledChanged: {
        if (!root.fingerprintUnlockEnabled) {
            root.faceFallbackPending = false;
            faceFallbackTimer.stop();
            stopFingerPam();
        } else if (GlobalStates.screenLocked) {
            root.fingerprintRetryCount = 0;
            tryFingerUnlock();
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
        id: biometricResumeTimer
        interval: 150
        repeat: true
        onTriggered: {
            if (!GlobalStates.screenLocked
                    || root.targetAction !== LockContext.ActionEnum.Unlock
                    || root.authenticationResolved) {
                root.cancelBiometricResume();
                return;
            }

            if (root.fingerprintResumePending) {
                if (!root.fingerprintUnlockEnabled || !root.fingerprintsConfigured) {
                    root.fingerprintResumePending = false;
                } else if (!fingerPam.active) {
                    root.fingerprintResumePending = false;
                    const started = root.tryFingerUnlock();
                    const elapsed = Date.now() - root.biometricResumeStartedAt;
                    root.logBiometric("Fingerprint rearm requested after " + elapsed
                        + " ms (PAM start " + (started ? "accepted" : "deferred") + ")");
                }
            }

            if (root.faceResumePending) {
                if (!root.faceUnlockEnabled || !root.faceAvailable) {
                    root.faceResumePending = false;
                } else if (!facePam.active) {
                    root.faceResumePending = false;
                    root.scheduleFaceUnlock();
                    const elapsed = Date.now() - root.biometricResumeStartedAt;
                    root.logBiometric("Face rearm scheduled after " + elapsed + " ms");
                }
            }

            if (!root.fingerprintResumePending && !root.faceResumePending) {
                biometricResumeTimer.stop();
                root.biometricResumeStartedAt = 0;
            }
        }
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
            if (facePam.active) facePam.abort();
            root.logBiometric("Face scan timed out");
            if (!root.authenticationResolved) root.failFaceUnlock();
        }
    }

    Timer {
        id: faceFallbackTimer
        interval: root.faceFallbackAnimationMs
        onTriggered: {
            if (!root.canFallbackToFingerprint()) {
                root.faceFallbackPending = false;
                return;
            }

            if (!fingerPam.active) {
                root.fingerprintRetryCount = 0;
                const started = root.tryFingerUnlock();
                root.logBiometric("Fingerprint fallback " + (started ? "started" : "deferred"));
            }
            root.faceFallbackPending = false;
            root.faceFallbackCompleted();
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
                if (root.fingerprintUnlockEnabled
                        && root.fingerprintsConfigured
                        && GlobalStates.screenLocked
                        && !fingerPam.active)
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
            if (result == PamResult.Success
                    && root.fingerprintSessionAllowed
                    && root.fingerprintUnlockEnabled) {
                root.logBiometric("Fingerprint PAM result: success");
                root.completeBiometricUnlock("fingerprint");
            } else if (!root.fingerprintSessionAllowed) {
                root.logBiometric("Ignored stale fingerprint PAM completion");
                return;
            } else if (result == PamResult.MaxTries) {
                root.logBiometric("Fingerprint PAM result: max-tries");
                root.fingerprintSessionAllowed = false;
                root.fingerprintState = root.fingerprintFailed;
            } else {
                root.logBiometric("Fingerprint PAM result: failed");
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
            if (!root.faceSessionAllowed) {
                root.logBiometric("Ignored stale face PAM completion");
                return;
            }
            root.logBiometric("Face PAM result: " + root.biometricResultName(result));
            if (result == PamResult.Success
                    && root.faceSessionAllowed
                    && root.faceUnlockEnabled) {
                root.completeBiometricUnlock("face");
            } else if (!root.authenticationResolved) {
                root.failFaceUnlock();
            }
        }
    }
}
