import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.panels.lock

// Unit-4's pixel-wave look, hosted by Vega's real Wayland session lock.
Rectangle {
    id: root
    required property LockContext context
    property bool closing: false
    property bool entered: false
    readonly property color ink: "#463f2e"
    readonly property color paper: "#d6cfb5"
    readonly property string dotFont: Qt.fontFamilies().includes("Ndot 57") ? "Ndot 57" : Appearance.font.family.monospace
    color: "#0b0906"

    function authenticate() {
        if (!context.currentText.length || context.unlockInProgress || context.authenticationResolved) return;
        context.resetTargetAction();
        context.tryUnlock();
    }

    Component.onCompleted: {
        root.entered = true;
        password.forceActiveFocus();
        reveal.play();
    }
    onClosingChanged: {
        if (!closing) return;
        reveal.stop();
        hide.play();
    }

    MediaPlayer {
        id: reveal
        objectName: "unit4Reveal"
        source: Quickshell.shellPath("assets/unit4-lock/wave_reveal.mp4")
        videoOutput: revealOutput
        audioOutput: null
        onPositionChanged: position => {
            if (!root.closing && reveal.duration > 0 && position >= reveal.duration - 34)
                reveal.pause();
        }
    }
    VideoOutput {
        id: revealOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        endOfStreamPolicy: VideoOutput.KeepLastFrame
        visible: !root.closing
    }
    MediaPlayer {
        id: hide
        objectName: "unit4Hide"
        source: Quickshell.shellPath("assets/unit4-lock/wave_hide.mp4")
        videoOutput: hideOutput
        audioOutput: null
    }
    VideoOutput {
        id: hideOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        endOfStreamPolicy: VideoOutput.KeepLastFrame
        visible: root.closing
    }

    component DotText: Text {
        color: root.ink
        font.family: root.dotFont
        font.pixelSize: 12
        font.letterSpacing: 2
    }

    Column {
        anchors { top: parent.top; left: parent.left; margins: 30 }
        spacing: 4
        DotText { text: root.closing ? "SESSION VERIFIED" : "SESSION LOCKED" }
        DotText { text: "NODE · " + SystemInfo.username.toUpperCase() }
        DotText { text: "セッションロック中"; font.pixelSize: 10 }
    }
    DotText {
        anchors { top: parent.top; right: parent.right; margins: 30 }
        text: Qt.formatDateTime(DateTime.clock.date, "yyyy / MM / dd")
    }
    DotText {
        anchors { bottom: parent.bottom; left: parent.left; margins: 30 }
        text: "UNIT-4 · VEGA / HYPRLAND"
    }
    DotText {
        anchors { bottom: parent.bottom; right: parent.right; margins: 30 }
        text: "AUTH · " + (root.context.authenticationResolved ? "VERIFIED" : "WAITING")
    }

    Rectangle {
        id: panel
        width: Math.min(380, root.width - 32)
        height: content.implicitHeight + 64
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.entered && !root.closing ? 0 : -200
        opacity: root.entered && !root.closing ? 1 : 0
        color: root.paper
        border.color: root.ink
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: root.closing ? 360 : 580; easing.type: Easing.OutExpo }
        }
        Behavior on opacity { NumberAnimation { duration: 280 } }

        Repeater {
            model: Math.max(0, Math.ceil(panel.width / 20))
            Rectangle {
                required property int index
                x: index * 20
                width: 1
                height: panel.height
                color: "#10463f2e"
            }
        }
        Repeater {
            model: Math.max(0, Math.ceil(panel.height / 20))
            Rectangle {
                required property int index
                y: index * 20
                height: 1
                width: panel.width
                color: "#10463f2e"
            }
        }
        Column {
            id: content
            anchors { top: parent.top; topMargin: 32; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 64
            spacing: 14
            Item {
                width: parent.width
                height: 76
                Rectangle {
                    anchors.centerIn: parent
                    width: 76; height: 76
                    color: "transparent"
                    border.color: root.ink
                    Rectangle { anchors.centerIn: parent; width: 44; height: 44; rotation: 45; color: root.ink }
                }
            }
            DotText { text: SystemInfo.username.toUpperCase(); anchors.horizontalCenter: parent.horizontalCenter }
            DotText {
                text: Qt.formatDateTime(DateTime.clock.date, "HH:mm")
                font.pixelSize: 46
                anchors.horizontalCenter: parent.horizontalCenter
            }
            DotText {
                text: Qt.formatDateTime(DateTime.clock.date, "yyyy / MM / dd")
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle { width: parent.width; height: 1; color: "#38463f2e" }
            TextField {
                id: password
                width: parent.width
                height: 42
                font.family: root.dotFont
                color: root.ink
                placeholderText: Translation.tr("Password")
                placeholderTextColor: "#7a7358"
                echoMode: TextInput.Password
                passwordCharacter: "·"
                text: root.context.currentText
                readOnly: root.context.unlockInProgress || root.context.authenticationResolved
                onTextEdited: root.context.currentText = text
                onAccepted: root.authenticate()
                Keys.onEscapePressed: root.context.clearText()
                Accessible.name: Translation.tr("Password")
                background: Rectangle { color: "transparent"; border.color: root.ink }
            }
            DotText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: 10
                color: "#6e2a2a"
                text: root.context.showFailure ? Translation.tr("Authentication failed")
                    : root.context.authenticationResolved ? Translation.tr("Verified")
                    : root.context.fingerprintStatusText || root.context.faceStatusText
            }
            Button {
                width: parent.width
                height: 42
                text: Translation.tr("Unlock")
                enabled: !root.context.unlockInProgress && !root.closing
                onClicked: root.authenticate()
                contentItem: DotText { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? "#e0c888" : "transparent"; border.color: root.ink }
            }
            Button {
                width: parent.width
                visible: root.context.fingerprintState === root.context.fingerprintFailed
                text: Translation.tr("Retry fingerprint")
                onClicked: root.context.retryFingerUnlock()
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "#e0c888"
            transform: Scale {
                origin.y: 0
                yScale: root.entered && !root.closing ? 0 : 1
                Behavior on yScale { NumberAnimation { duration: root.closing ? 210 : 460; easing.type: Easing.OutExpo } }
            }
        }
    }
    Connections {
        target: root.context
        function onShouldReFocus() { password.forceActiveFocus(); }
    }
}
