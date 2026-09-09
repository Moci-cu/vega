pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    // Ensure Idle service is always loaded so the idle inhibitor works in both panel families
    // (e.g. even when "Keep right sidebar loaded" is off in ii).
    Item {
        id: idleServiceAnchor
        property bool _ensureIdleLoaded: Idle.inhibit
    }

    required property Component lockSurface
    property alias context: lockContext
    property int unlockAnimationDuration: 0
    property bool closing: false

    function finishUnlock() {
        if (!root.closing || !lockContext.authenticationResolved) return;
        if (Config.options.lock.security.unlockKeyring && lockContext.passwordAuthenticated)
            root.unlockKeyring();
        GlobalStates.screenLocked = false;
        lockContext.reset();
        root.closing = false;
        if (lockContext.alsoInhibitIdle) {
            lockContext.alsoInhibitIdle = false;
            Idle.toggleInhibit(true);
        }
    }

    Timer {
        id: unlockAnimationTimer
        interval: root.unlockAnimationDuration
        onTriggered: root.finishUnlock()
    }
    property Component sessionLockSurface: WlSessionLockSurface {
        id: sessionLockSurface
        color: "transparent"
        Loader {
            active: GlobalStates.screenLocked
            anchors.fill: parent
            opacity: active ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
            sourceComponent: root.lockSurface
        }
    }

    Process {
        id: unlockKeyringProc
        onExited: (exitCode, exitStatus) => {
            KeyringStorage.fetchKeyringData();
        }
    }
    function unlockKeyring() {
        unlockKeyringProc.exec({
            environment: ({
                "UNLOCK_PASSWORD": lockContext.currentText
            }),
            command: ["bash", "-c", Quickshell.shellPath("scripts/keyring/unlock.sh")]
        })
    }

    // This stores all the information shared between the lock surfaces on each screen.
    // https://github.com/quickshell-mirror/quickshell-examples/tree/master/lockscreen
    LockContext {
        id: lockContext

        Connections {
            target: GlobalStates
            function onScreenLockedChanged() {
                if (GlobalStates.screenLocked) {
                    root.closing = false;
                    unlockAnimationTimer.stop();
                    if (GlobalStates.overlayOpen) {
                        GlobalStates.overlayOpen = false;
                    }
                    lockContext.reset();
                }
            }
        }

        onUnlocked: (targetAction) => {
            // Perform the target action if it's not just unlocking
            if (targetAction == LockContext.ActionEnum.Poweroff) {
                Session.poweroff();
                return;
            } else if (targetAction == LockContext.ActionEnum.Reboot) {
                Session.reboot();
                return;
            }

            if (!lockContext.authenticationResolved || root.closing) return;
            root.closing = true;
            // Keep the session locked throughout the exit video. A fixed deadline
            // also completes authenticated unlock if the media decoder fails.
            if (root.unlockAnimationDuration > 0)
                unlockAnimationTimer.start();
            else
                root.finishUnlock();
        }
    }

    WlSessionLock {
        id: lock
        locked: GlobalStates.screenLocked
        surface: root.sessionLockSurface
    }

    function lock() {
        if (Config.options.lock.useHyprlock) {
            Quickshell.execDetached(["bash", "-c", "pidof hyprlock || hyprlock"]);
            return;
        }
        GlobalStates.screenLocked = true;
    }

    IpcHandler {
        target: "lock"

        function activate(): void {
            root.lock();
        }
        function focus(): void {
            lockContext.shouldReFocus();
        }
    }

    GlobalShortcut {
        name: "lock"
        description: "Locks the screen"

        onPressed: {
            root.lock()
        }
    }

    GlobalShortcut {
        name: "lockFocus"
        description: "Re-focuses the lock screen. This is because Hyprland after waking up for whatever reason"
            + "decides to keyboard-unfocus the lock screen"

        onPressed: {
            lockContext.resumeBiometricUnlock();
            lockContext.shouldReFocus();
        }
    }

    function initIfReady() {
        if (!Config.ready || !Persistent.ready) return;
        if (Config.options.lock.launchOnStartup && Persistent.isNewHyprlandInstance) {
            root.lock();
        } else {
            KeyringStorage.fetchKeyringData();
        }
    }

    Component.onCompleted: initIfReady()

    Connections {
        target: Config
        function onReadyChanged() {
            root.initIfReady();
        }
    }
    Connections {
        target: Persistent
        function onReadyChanged() {
            root.initIfReady();
        }
    }
}
