import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool durationError: false
    readonly property bool resumeState: !TimerService.pomodoroRunning && TimerService.pomodoroSecondsLeft !== TimerService.pomodoroLapDuration
    readonly property color heroForeground: TimerService.pomodoroBreak
        ? Appearance.colors.colOnTertiaryContainer
        : Appearance.colors.colOnSecondaryContainer

    function syncDurationText() {
        if (!durationField.activeFocus)
            durationField.text = Math.floor(TimerService.focusTime / 60).toString();
    }

    function applyDuration() {
        if (!TimerService.setFocusMinutes(durationField.text)) {
            durationError = true;
            syncDurationText();
            return;
        }
        durationError = false;
        syncDurationText();
    }

    function adjustDuration(delta) {
        const entered = Number(durationField.text);
        const current = isNaN(entered) ? Math.floor(TimerService.focusTime / 60) : entered;
        durationField.text = Math.max(1, Math.min(1440, current + delta)).toString();
        applyDuration();
    }

    Connections {
        target: TimerService

        function onFocusTimeChanged() { root.syncDurationText(); }
        function onPomodoroDurationEditableChanged() {
            root.durationError = false;
            root.syncDurationText();
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 14
            rightMargin: 14
            bottomMargin: 8
        }
        spacing: 8

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 184
            implicitHeight: 174

            Canvas {
                id: progressRing

                anchors.centerIn: parent
                width: 174
                height: 174

                property real value: TimerService.pomodoroLapDuration > 0
                    ? 1 - TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration
                    : 0
                property real animatedValue: value
                property real wavePhase: 0
                property real lineWidth: 7
                property real amplitude: 4
                property int waveCount: 12
                property color progressColor: root.heroForeground
                property color trackColor: Appearance.colors.colLayer3

                Behavior on animatedValue {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.Linear
                    }
                }

                NumberAnimation on wavePhase {
                    from: 0
                    to: Math.PI * 2
                    duration: 2000
                    loops: Animation.Infinite
                    running: TimerService.pomodoroRunning && progressRing.animatedValue > 0
                    easing.type: Easing.Linear
                }

                onPaint: {
                    const context = getContext("2d");
                    const progress = Math.max(0, Math.min(1, animatedValue));
                    const centerX = width / 2;
                    const centerY = height / 2;
                    const radius = Math.min(width, height) / 2 - lineWidth / 2 - amplitude - 2;
                    const startAngle = -Math.PI / 2;
                    const sweepAngle = Math.PI * 2 * progress;
                    const gapAngle = Math.PI / 18;

                    context.clearRect(0, 0, width, height);
                    context.lineWidth = lineWidth;
                    context.lineCap = "round";
                    context.lineJoin = "round";

                    context.strokeStyle = trackColor;
                    context.beginPath();
                    if (progress <= 0) {
                        context.arc(centerX, centerY, radius, startAngle, startAngle + Math.PI * 2);
                        context.closePath();
                    } else if (Math.PI * 2 - sweepAngle > gapAngle * 2) {
                        context.arc(centerX, centerY, radius, startAngle + sweepAngle + gapAngle, startAngle + Math.PI * 2 - gapAngle);
                    }
                    context.stroke();

                    if (progress <= 0)
                        return;

                    const steps = Math.max(2, Math.ceil(radius * sweepAngle / 2));
                    context.strokeStyle = progressColor;
                    context.beginPath();
                    for (let i = 0; i <= steps; i++) {
                        const ratio = i / steps;
                        const angle = startAngle + sweepAngle * ratio;
                        const wave = Math.sin((angle - startAngle) * waveCount + wavePhase) * amplitude;
                        const x = centerX + Math.cos(angle) * (radius + wave);
                        const y = centerY + Math.sin(angle) * (radius + wave);
                        if (i === 0) context.moveTo(x, y);
                        else context.lineTo(x, y);
                    }
                    if (progress >= 1)
                        context.closePath();
                    context.stroke();
                }

                onAnimatedValueChanged: requestPaint()
                onWavePhaseChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onProgressColorChanged: requestPaint()
                onTrackColorChanged: requestPaint()
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        const minutes = Math.floor(TimerService.pomodoroSecondsLeft / 60).toString().padStart(2, "0");
                        const seconds = Math.floor(TimerService.pomodoroSecondsLeft % 60).toString().padStart(2, "0");
                        return `${minutes}:${seconds}`;
                    }
                    font.pixelSize: 42
                    font.weight: Font.DemiBold
                    color: root.heroForeground
                }
            }

            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 2
                    bottomMargin: 4
                }
                implicitWidth: 48
                implicitHeight: 28
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: `${TimerService.pomodoroCycle + 1} / ${TimerService.cyclesBeforeLongBreak}`
                    color: Appearance.colors.colOnPrimaryContainer
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            RippleButton {
                implicitHeight: 46
                implicitWidth: root.resumeState ? 46 : 156
                scale: down ? 0.94 : hovered ? 1.03 : 1
                buttonRadius: Appearance.rounding.full
                buttonRadiusPressed: Appearance.rounding.normal
                Accessible.name: root.resumeState ? Translation.tr("Resume") : TimerService.pomodoroRunning ? Translation.tr("Pause") : Translation.tr("Start")
                onClicked: TimerService.togglePomodoro()
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive

                Behavior on implicitWidth {
                    animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
                }

                Behavior on scale {
                    animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
                }

                contentItem: Item {
                    MaterialSymbol {
                        visible: root.resumeState
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "play_arrow"
                        iconSize: Appearance.font.pixelSize.larger
                        fill: 1
                        color: Appearance.colors.colOnPrimary
                        transform: Translate { x: 1 }
                    }

                    RowLayout {
                        visible: !root.resumeState
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: TimerService.pomodoroRunning ? "pause" : "play_arrow"
                            iconSize: Appearance.font.pixelSize.larger
                            fill: 1
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            text: TimerService.pomodoroRunning ? Translation.tr("Pause") : Translation.tr("Start")
                            color: Appearance.colors.colOnPrimary
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            RippleButton {
                implicitHeight: 46
                implicitWidth: 46
                scale: down ? 0.92 : hovered ? 1.04 : 1
                buttonRadius: Appearance.rounding.full
                buttonRadiusPressed: Appearance.rounding.normal
                enabled: TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration
                    || TimerService.pomodoroCycle > 0
                    || TimerService.pomodoroBreak
                onClicked: TimerService.resetPomodoro()
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active

                Behavior on scale {
                    animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
                }

                contentItem: MaterialSymbol {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "restart_alt"
                    iconSize: Appearance.font.pixelSize.larger
                    fill: 1
                    color: Appearance.colors.colOnLayer2
                }

                StyledToolTip { text: Translation.tr("Reset") }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 244
            implicitHeight: 42
            radius: Appearance.rounding.full
            color: root.durationError ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer2
            enabled: TimerService.pomodoroDurationEditable
            opacity: TimerService.pomodoroDurationEditable ? 1 : 0.45

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 5
                }
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Focus length")
                    color: root.durationError ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    onClicked: root.adjustDuration(-5)
                    contentItem: MaterialSymbol {
                        text: "remove"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }

                ToolbarTextField {
                    id: durationField

                    implicitWidth: 42
                    implicitHeight: 32
                    padding: 4
                    horizontalAlignment: TextInput.AlignHCenter
                    text: Math.floor(TimerService.focusTime / 60).toString()
                    Accessible.name: Translation.tr("Focus duration in minutes")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 1440 }
                    colBackground: Appearance.colors.colLayer1
                    onTextEdited: root.durationError = false
                    onEditingFinished: {
                        if (acceptableInput) root.applyDuration();
                        else {
                            root.durationError = true;
                            root.syncDurationText();
                        }
                    }
                }

                StyledText {
                    text: Translation.tr("min")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    onClicked: root.adjustDuration(5)
                    contentItem: MaterialSymbol {
                        text: "add"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }
    }
}
