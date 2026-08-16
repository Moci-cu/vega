import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.panels.lock
import qs.modules.ii.bar as Bar
import Quickshell
import Quickshell.Services.SystemTray

MouseArea {
    id: root
    required property LockContext context
    property bool active: false
    property bool showInputField: active || context.currentText.length > 0
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower

    // Force focus on entry
    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }
    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus();
        }
    }
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: mouse => {
        forceFieldFocus();
    }
    onPositionChanged: mouse => {
        forceFieldFocus();
    }

    // Toolbar appearing animation
    property real toolbarScale: 0.9
    property real toolbarOpacity: 0
    Behavior on toolbarScale {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
    }
    Behavior on toolbarOpacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    // Init
    Component.onCompleted: {
        forceFieldFocus();
        toolbarScale = 1;
        toolbarOpacity = 1;
    }

    // Key presses
    property bool ctrlHeld: false
    Keys.onPressed: event => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = true;
        }
        if (event.key === Qt.Key_Escape) { // Esc to clear
            root.context.currentText = "";
        } 
        forceFieldFocus();
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = false;
        }
        forceFieldFocus();
    }

    // RippleButton {
    //     anchors {
    //         top: parent.top
    //         left: parent.left
    //         leftMargin: 10
    //         topMargin: 10
    //     }
    //     implicitHeight: 40
    //     colBackground: Appearance.colors.colLayer2
    //     onClicked: {
    //         context.unlocked(LockContext.ActionEnum.Unlock);
    //         GlobalStates.screenLocked = false;
    //     }
    //     contentItem: StyledText {
    //         text: "[[ DEBUG BYPASS ]]"
    //     }
    // }

    Item {
        id: biometricIndicator

        readonly property bool succeeded: root.context.fingerprintState === root.context.fingerprintSuccess
            || root.context.faceState === root.context.faceSuccess
        readonly property bool faceActive: !biometricIndicator.succeeded
            && (root.context.faceState === root.context.faceWaiting
                || root.context.faceState === root.context.faceScanning)
        readonly property bool fingerprintActive: !biometricIndicator.succeeded
            && (root.context.fingerprintState === root.context.fingerprintScanning
                || root.context.fingerprintState === root.context.fingerprintRetryPending)
        readonly property bool faceFailureShowing: !biometricIndicator.succeeded
            && root.context.faceFallbackPending
        readonly property bool scanning: !biometricIndicator.succeeded
            && !biometricIndicator.faceFailureShowing
            && (biometricIndicator.faceActive || biometricIndicator.fingerprintActive)
        readonly property bool dualScanning: biometricIndicator.faceActive
            && biometricIndicator.fingerprintActive
        readonly property bool fingerprintFinished: !root.context.fingerprintUnlockEnabled
            || !root.context.fingerprintsConfigured
            || root.context.fingerprintState === root.context.fingerprintFailed
        readonly property bool faceFinished: !root.context.faceUnlockEnabled
            || !root.context.faceAvailable
            || root.context.faceState === root.context.faceFailed
        readonly property bool failed: !biometricIndicator.succeeded
            && !biometricIndicator.faceFailureShowing
            && biometricIndicator.fingerprintFinished
            && biometricIndicator.faceFinished
        readonly property color activeColor: biometricIndicator.faceActive
            ? Appearance.colors.colPrimary
            : Appearance.colors.colSecondary

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 40
        }
        width: 88
        height: 88
        visible: root.context.targetAction === LockContext.ActionEnum.Unlock
            && ((root.context.fingerprintUnlockEnabled && root.context.fingerprintsConfigured)
                || (root.context.faceUnlockEnabled && root.context.faceAvailable))
        opacity: root.toolbarOpacity

        Repeater {
            model: 2

            delegate: Rectangle {
                id: biometricRipple
                required property int index

                anchors.centerIn: parent
                width: 60
                height: 60
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: biometricIndicator.activeColor
                opacity: 0
                scale: 0.82

                SequentialAnimation {
                    running: biometricIndicator.scanning
                    loops: Animation.Infinite
                    onStopped: {
                        biometricRipple.opacity = 0;
                        biometricRipple.scale = 0.82;
                    }

                    PauseAnimation { duration: biometricRipple.index * 600 }
                    ParallelAnimation {
                        NumberAnimation {
                            target: biometricRipple
                            property: "scale"
                            from: 0.82
                            to: 1.4
                            duration: 1200
                            easing.type: Easing.OutQuad
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: biometricRipple
                                property: "opacity"
                                from: 0
                                to: 0.42
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: biometricRipple
                                property: "opacity"
                                to: 0
                                duration: 1020
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    PauseAnimation {
                        duration: (1 - biometricRipple.index) * 600
                    }
                }
            }
        }

        Rectangle {
            id: biometricSuccessHalo

            anchors.centerIn: parent
            width: 64
            height: 64
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colPrimary
            opacity: 0
            scale: 0.72
        }

        Rectangle {
            id: biometricFailureHalo

            anchors.centerIn: parent
            width: 64
            height: 64
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colError
            opacity: 0
            scale: 0.72
        }

        Rectangle {
            id: biometricBadge

            anchors.centerIn: parent
            width: 60
            height: 60
            radius: width / 2
            color: biometricIndicator.succeeded
                ? Appearance.colors.colPrimary
                : biometricIndicator.faceFailureShowing || biometricIndicator.failed
                ? Appearance.colors.colErrorContainer
                : biometricIndicator.faceActive
                ? Appearance.colors.colPrimaryContainer
                : biometricIndicator.fingerprintActive
                ? Appearance.colors.colSecondaryContainer
                : Appearance.colors.colSurfaceContainerHigh
            border.width: biometricIndicator.scanning ? 0 : 1
            border.color: ColorUtils.transparentize(Appearance.colors.colOutline, 0.65)

            Behavior on color {
                ColorAnimation { duration: 220 }
            }
            Behavior on border.width {
                NumberAnimation { duration: 160 }
            }

            transform: [
                Scale {
                    id: biometricBreathingTransform

                    origin.x: biometricBadge.width / 2
                    origin.y: biometricBadge.height / 2
                },
                Translate {
                    id: biometricShakeTransform
                }
            ]

            MaterialSymbol {
                id: biometricStateIcon

                anchors.centerIn: parent
                text: biometricIndicator.succeeded
                    ? "check"
                    : biometricIndicator.faceFailureShowing
                    ? "face_retouching_off"
                    : biometricIndicator.faceActive
                    ? "face"
                    : biometricIndicator.fingerprintActive
                    ? "fingerprint"
                    : biometricIndicator.failed
                    ? "lock"
                    : root.context.faceUnlockEnabled && root.context.faceAvailable
                    ? "face"
                    : "lock"
                iconSize: biometricIndicator.succeeded ? 34 : 32
                fill: biometricIndicator.scanning || biometricIndicator.succeeded ? 1 : 0
                animateChange: true
                color: biometricIndicator.succeeded
                    ? Appearance.colors.colOnPrimary
                    : biometricIndicator.faceFailureShowing || biometricIndicator.failed
                    ? Appearance.colors.colOnErrorContainer
                    : biometricIndicator.faceActive
                    ? Appearance.colors.colOnPrimaryContainer
                    : biometricIndicator.fingerprintActive
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnSurfaceVariant
            }

            Rectangle {
                id: secondaryBiometricBadge

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: -4
                    bottomMargin: -4
                }
                width: 24
                height: 24
                radius: width / 2
                visible: biometricIndicator.dualScanning
                color: Appearance.colors.colLayer1
                border.width: 2
                border.color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "fingerprint"
                    iconSize: 15
                    fill: 1
                    color: Appearance.colors.colPrimary
                }
            }
        }

        SequentialAnimation {
            id: biometricBreathingAnimation

            running: biometricIndicator.scanning
            loops: Animation.Infinite
            onStopped: {
                biometricBreathingTransform.xScale = 1;
                biometricBreathingTransform.yScale = 1;
            }

            ParallelAnimation {
                NumberAnimation {
                    target: biometricBreathingTransform
                    property: "xScale"
                    from: 1
                    to: 1.04
                    duration: 750
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: biometricBreathingTransform
                    property: "yScale"
                    from: 1
                    to: 1.04
                    duration: 750
                    easing.type: Easing.InOutSine
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: biometricBreathingTransform
                    property: "xScale"
                    from: 1.04
                    to: 1
                    duration: 750
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: biometricBreathingTransform
                    property: "yScale"
                    from: 1.04
                    to: 1
                    duration: 750
                    easing.type: Easing.InOutSine
                }
            }
        }

        onSucceededChanged: {
            if (biometricIndicator.succeeded) {
                biometricSuccessPop.restart();
                biometricSuccessRipple.restart();
            }
        }
        onFailedChanged: {
            if (biometricIndicator.failed) {
                biometricFailureShake.restart();
                biometricFailureRipple.restart();
            }
        }

        Connections {
            target: root.context

            function onFaceFallbackStarted() {
                biometricFailureShake.restart();
                biometricFailureRipple.restart();
            }

            function onFaceFallbackCompleted() {
                if (!biometricIndicator.succeeded && biometricIndicator.fingerprintActive)
                    biometricFallbackPop.restart();
            }
        }

        SequentialAnimation {
            id: biometricSuccessPop

            NumberAnimation {
                target: biometricBadge
                property: "scale"
                from: 0.78
                to: 1.14
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: biometricBadge
                property: "scale"
                to: 1
                duration: 240
                easing.type: Easing.OutBack
            }
        }

        ParallelAnimation {
            id: biometricSuccessRipple

            NumberAnimation {
                target: biometricSuccessHalo
                property: "scale"
                from: 0.72
                to: 1.38
                duration: 420
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: biometricSuccessHalo
                    property: "opacity"
                    from: 0
                    to: 0.8
                    duration: 90
                }
                NumberAnimation {
                    target: biometricSuccessHalo
                    property: "opacity"
                    to: 0
                    duration: 330
                    easing.type: Easing.OutCubic
                }
            }
        }

        ParallelAnimation {
            id: biometricFailureRipple

            NumberAnimation {
                target: biometricFailureHalo
                property: "scale"
                from: 0.72
                to: 1.28
                duration: 420
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: biometricFailureHalo
                    property: "opacity"
                    from: 0
                    to: 0.72
                    duration: 90
                }
                NumberAnimation {
                    target: biometricFailureHalo
                    property: "opacity"
                    to: 0
                    duration: 330
                    easing.type: Easing.OutCubic
                }
            }
        }

        SequentialAnimation {
            id: biometricFallbackPop

            NumberAnimation {
                target: biometricBadge
                property: "scale"
                from: 0.9
                to: 1.08
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: biometricBadge
                property: "scale"
                to: 1
                duration: 180
                easing.type: Easing.OutBack
            }
        }

        SequentialAnimation {
            id: biometricFailureShake

            NumberAnimation { target: biometricShakeTransform; property: "x"; to: -6; duration: 55 }
            NumberAnimation { target: biometricShakeTransform; property: "x"; to: 6; duration: 80 }
            NumberAnimation { target: biometricShakeTransform; property: "x"; to: -4; duration: 70 }
            NumberAnimation { target: biometricShakeTransform; property: "x"; to: 3; duration: 65 }
            NumberAnimation { target: biometricShakeTransform; property: "x"; to: 0; duration: 60 }
        }
    }

    // Main toolbar: password box
    Toolbar {
        id: mainIsland
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 20
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        // Fingerprint
        Loader {
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.alignment: Qt.AlignVCenter
            active: root.context.fingerprintUnlockEnabled
                && root.context.fingerprintsConfigured
                && root.context.targetAction === LockContext.ActionEnum.Unlock
            visible: active

            sourceComponent: RowLayout {
                spacing: 4

                IconToolbarButton {
                    id: fingerprintButton
                    readonly property bool accepted: root.context.fingerprintState === root.context.fingerprintSuccess
                    readonly property bool retryAllowed: root.context.fingerprintState !== root.context.fingerprintScanning
                        && root.context.fingerprintState !== root.context.fingerprintRetryPending
                        && !fingerprintButton.accepted

                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    pointingHandCursor: fingerprintButton.retryAllowed
                    toggled: fingerprintButton.accepted
                    text: fingerprintButton.accepted
                        ? "check_circle"
                        : root.context.fingerprintState === root.context.fingerprintFailed
                        ? "fingerprint_off"
                        : "fingerprint"
                    iconFill: root.context.fingerprintState === root.context.fingerprintScanning
                        || fingerprintButton.accepted
                    colBackgroundToggled: Appearance.colors.colPrimary
                    colBackgroundToggledHover: Appearance.colors.colPrimary
                    colText: fingerprintButton.accepted
                        ? Appearance.colors.colOnPrimary
                        : root.context.fingerprintState === root.context.fingerprintFailed
                        ? Appearance.colors.colError
                        : Appearance.colors.colOnSurfaceVariant
                    onClicked: {
                        if (fingerprintButton.retryAllowed)
                            root.context.retryFingerUnlock();
                    }

                    Connections {
                        target: root.context
                        function onFingerprintStateChanged() {
                            if (root.context.fingerprintState === root.context.fingerprintSuccess)
                                fingerprintSuccessPulse.restart();
                        }
                    }

                    SequentialAnimation {
                        id: fingerprintSuccessPulse

                        NumberAnimation {
                            target: fingerprintButton
                            property: "scale"
                            from: 1
                            to: 1.18
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: fingerprintButton
                            property: "scale"
                            to: 1
                            duration: 220
                            easing.type: Easing.OutBack
                        }
                    }

                    StyledToolTip {
                        text: root.context.fingerprintStatusText
                    }
                }
            }
        }

        // Face unlock
        Loader {
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.alignment: Qt.AlignVCenter
            active: root.context.faceUnlockEnabled
                && root.context.faceAvailable
                && root.context.targetAction === LockContext.ActionEnum.Unlock
            visible: active

            sourceComponent: RowLayout {
                spacing: 4

                IconToolbarButton {
                    id: faceButton
                    readonly property bool accepted: root.context.faceState === root.context.faceSuccess
                    readonly property bool retryAllowed: root.context.faceState !== root.context.faceScanning
                        && !faceButton.accepted

                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    pointingHandCursor: faceButton.retryAllowed
                    toggled: faceButton.accepted
                    text: faceButton.accepted
                        ? "check_circle"
                        : root.context.faceState === root.context.faceFailed
                        ? "face_retouching_off"
                        : "face"
                    iconFill: root.context.faceState === root.context.faceScanning
                        || faceButton.accepted
                    colBackgroundToggled: Appearance.colors.colPrimary
                    colBackgroundToggledHover: Appearance.colors.colPrimary
                    colText: faceButton.accepted
                        ? Appearance.colors.colOnPrimary
                        : root.context.faceState === root.context.faceFailed
                        ? Appearance.colors.colError
                        : Appearance.colors.colOnSurfaceVariant
                    onClicked: {
                        if (faceButton.retryAllowed)
                            root.context.retryFaceUnlock();
                    }

                    Connections {
                        target: root.context
                        function onFaceStateChanged() {
                            if (root.context.faceState === root.context.faceSuccess)
                                faceSuccessPulse.restart();
                        }
                    }

                    SequentialAnimation {
                        id: faceSuccessPulse

                        NumberAnimation {
                            target: faceButton
                            property: "scale"
                            from: 1
                            to: 1.18
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: faceButton
                            property: "scale"
                            to: 1
                            duration: 220
                            easing.type: Easing.OutBack
                        }
                    }

                    StyledToolTip {
                        text: root.context.faceStatusText
                    }
                }
            }
        }

        ToolbarTextField {
            id: passwordBox
            Layout.rightMargin: -Layout.leftMargin
            placeholderText: GlobalStates.screenUnlockFailed ? Translation.tr("Incorrect password") : Translation.tr("Enter password")

            // Style
            clip: true
            font.pixelSize: Appearance.font.pixelSize.small
            selectedTextColor: materialShapeChars ? "transparent" : Appearance.colors.colOnSecondaryContainer
            selectionColor: materialShapeChars ? "transparent" : Appearance.colors.colSecondaryContainer

            // Password
            enabled: !root.context.unlockInProgress
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData

            // Synchronizing (across monitors) and unlocking
            onTextChanged: root.context.currentText = this.text
            onAccepted: {
                root.context.tryUnlock(ctrlHeld);
            }
            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    passwordBox.text = root.context.currentText;
                }
            }

            Keys.onPressed: event => {
                root.context.resetClearTimer();
            }
            
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: passwordBox.width - 8
                    height: passwordBox.height
                    radius: height / 2
                }
            }

            // Shake when wrong password
            ErrorShakeAnimation {
                id: wrongPasswordShakeAnim
                target: passwordBox
            }
            Connections {
                target: GlobalStates
                function onScreenUnlockFailedChanged() {
                    if (GlobalStates.screenUnlockFailed) wrongPasswordShakeAnim.restart();
                }
            }

            // We're drawing dots manually
            property bool materialShapeChars: Config.options.lock.materialShapeChars
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, materialShapeChars ? 1 : 0)
            Loader {
                active: passwordBox.materialShapeChars
                anchors {
                    fill: parent
                    leftMargin: passwordBox.padding
                    rightMargin: passwordBox.padding
                }
                sourceComponent: PasswordChars {
                    length: root.context.currentText.length
                    selectionStart: passwordBox.selectionStart
                    selectionEnd: passwordBox.selectionEnd
                    cursorPosition: passwordBox.cursorPosition
                }
            }
        }

        ToolbarButton {
            id: confirmButton
            implicitWidth: height
            toggled: true
            enabled: !root.context.unlockInProgress
            colBackgroundToggled: Appearance.colors.colPrimary

            onClicked: root.context.tryUnlock()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: 24
                text: {
                    if (root.context.targetAction === LockContext.ActionEnum.Unlock) {
                        return root.ctrlHeld ? "coffee" : "arrow_right_alt";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                        return "power_settings_new";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                        return "restart_alt";
                    }
                }
                color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
            }
        }
    }

    // Left toolbar
    Toolbar {
        id: leftIsland
        anchors {
            right: mainIsland.left
            top: mainIsland.top
            bottom: mainIsland.bottom
            rightMargin: 10
        }
        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        // Username
        IconAndTextPair {
            Layout.leftMargin: 8
            icon: "account_circle"
            text: SystemInfo.username
        }

        // Keyboard layout (Xkb)
        Loader {
            Layout.rightMargin: 8
            Layout.fillHeight: true

            active: true
            visible: active

            sourceComponent: Row {
                spacing: 8

                MaterialSymbol {
                    id: keyboardIcon
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 1
                    text: "keyboard_alt"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnSurfaceVariant
                }
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: StyledText {
                        text: HyprlandXkb.currentLayoutCode
                        color: Appearance.colors.colOnSurfaceVariant
                        animateChange: true
                    }
                }
            }
        }

        // Keyboard layout (Fcitx)
        Bar.SysTray {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            showSeparator: false
            showOverflowMenu: false
            pinnedItems: SystemTray.items.values.filter(i => i.id == "Fcitx")
            visible: pinnedItems.length > 0
        }
    }

    // Right toolbar
    Toolbar {
        id: rightIsland
        anchors {
            left: mainIsland.right
            top: mainIsland.top
            bottom: mainIsland.bottom
            leftMargin: 10
        }

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        IconAndTextPair {
            visible: Battery.available
            icon: Battery.isCharging ? "bolt" : "battery_android_full"
            text: Math.round(Battery.percentage * 100)
            color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
        }

        IconToolbarButton {
            id: sleepButton
            onClicked: Session.suspend()
            text: "dark_mode"
        }

        PasswordGuardedIconToolbarButton {
            id: powerButton
            text: "power_settings_new"
            targetAction: LockContext.ActionEnum.Poweroff
        }

        PasswordGuardedIconToolbarButton {
            id: rebootButton
            text: "restart_alt"
            targetAction: LockContext.ActionEnum.Reboot
        }
    }

    component PasswordGuardedIconToolbarButton: IconToolbarButton {
        id: guardedBtn
        required property var targetAction

        enabled: !root.context.unlockInProgress
        toggled: root.context.targetAction === guardedBtn.targetAction

        onClicked: {
            if (!root.requirePasswordToPower) {
                root.context.unlocked(guardedBtn.targetAction);
                return;
            }
            if (root.context.targetAction === guardedBtn.targetAction) {
                root.context.resetTargetAction();
            } else {
                root.context.targetAction = guardedBtn.targetAction;
                root.context.shouldReFocus();
            }
        }
    }

    component IconAndTextPair: Row {
        id: pair
        required property string icon
        required property string text
        property color color: Appearance.colors.colOnSurfaceVariant

        spacing: 4
        Layout.fillHeight: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 1
            text: pair.icon
            iconSize: Appearance.font.pixelSize.huge
            animateChange: true
            color: pair.color
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pair.text
            color: pair.color
        }
    }
}
