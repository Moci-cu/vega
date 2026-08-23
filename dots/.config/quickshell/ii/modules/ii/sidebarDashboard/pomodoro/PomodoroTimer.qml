import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool durationError: false
    readonly property color heroContainer: TimerService.pomodoroBreak
        ? Appearance.colors.colTertiaryContainer
        : Appearance.colors.colSecondaryContainer
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

            MaterialShape {
                anchors.centerIn: parent
                width: 154
                height: 154
                shape: TimerService.pomodoroRunning
                    ? MaterialShape.Shape.Cookie9Sided
                    : MaterialShape.Shape.Cookie4Sided
                color: root.heroContainer
            }

            CircularProgress {
                anchors.centerIn: parent
                implicitSize: 174
                lineWidth: 7
                value: TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration
                colPrimary: root.heroForeground
                colSecondary: Appearance.colors.colLayer3
                enableAnimation: true
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
                    font.weight: Font.Medium
                    color: root.heroForeground
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.pomodoroLongBreak
                        ? Translation.tr("Long break")
                        : TimerService.pomodoroBreak
                            ? Translation.tr("Break")
                            : Translation.tr("Focus")
                    font.pixelSize: Appearance.font.pixelSize.normal
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
                implicitWidth: 156
                buttonRadius: Appearance.rounding.full
                buttonRadiusPressed: Appearance.rounding.normal
                onClicked: TimerService.togglePomodoro()
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colRipple: Appearance.colors.colPrimaryActive

                contentItem: RowLayout {
                    spacing: 6

                    MaterialSymbol {
                        text: TimerService.pomodoroRunning ? "pause" : "play_arrow"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnPrimary
                    }
                    StyledText {
                        text: TimerService.pomodoroRunning
                            ? Translation.tr("Pause")
                            : TimerService.pomodoroSecondsLeft === TimerService.focusTime
                                ? Translation.tr("Start")
                                : Translation.tr("Resume")
                        color: Appearance.colors.colOnPrimary
                        font.weight: Font.Medium
                    }
                }
            }

            RippleButton {
                implicitHeight: 46
                implicitWidth: 46
                buttonRadius: Appearance.rounding.full
                buttonRadiusPressed: Appearance.rounding.normal
                enabled: TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration
                    || TimerService.pomodoroCycle > 0
                    || TimerService.pomodoroBreak
                onClicked: TimerService.resetPomodoro()
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active

                contentItem: MaterialSymbol {
                    text: "restart_alt"
                    iconSize: Appearance.font.pixelSize.larger
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
                    enabled: TimerService.pomodoroDurationEditable
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
                    enabled: TimerService.pomodoroDurationEditable
                    Accessible.name: Translation.tr("Focus duration in minutes")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 1440 }
                    colBackground: Appearance.colors.colLayer1
                    onTextEdited: root.durationError = false
                    onAccepted: root.applyDuration()
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
                    enabled: TimerService.pomodoroDurationEditable
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
