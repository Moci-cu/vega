pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    readonly property bool paused: !TimerService.pomodoroRunning
        && TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration
    readonly property int secondsLeft: Math.max(0, TimerService.pomodoroSecondsLeft)
    readonly property string displayTime: {
        const hours = Math.floor(root.secondsLeft / 3600).toString().padStart(2, "0");
        const minutes = Math.floor(root.secondsLeft / 60 % 60).toString().padStart(2, "0");
        const seconds = Math.floor(root.secondsLeft % 60).toString().padStart(2, "0");
        return `${hours}:${minutes}:${seconds}`;
    }
    readonly property string statusText: TimerService.pomodoroBreak
        ? Translation.tr("Break") : TimerService.pomodoroRunning
            ? Translation.tr("Running") : root.paused
                ? Translation.tr("Paused") : Translation.tr("Ready")
    readonly property color accentColor: TimerService.pomodoroBreak
        ? Appearance.colors.colTertiary : Appearance.colors.colPrimary

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(0.02, 0.025, 0.035, 0.16)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 15
                color: Qt.rgba(0.56, 0.74, 0.92, 0.12)
                border.width: 0.8
                border.color: Qt.rgba(0.82, 0.92, 1, 0.16)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "timer"
                    iconSize: 25
                    color: root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: Translation.tr("Timer")
                    color: Qt.rgba(1, 1, 1, 0.94)
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: Translation.tr("Try “set a timer for 60 minutes”")
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            Rectangle {
                implicitWidth: timerStatus.implicitWidth + 20
                implicitHeight: 28
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.07)

                StyledText {
                    id: timerStatus

                    anchors.centerIn: parent
                    text: root.statusText
                    color: root.accentColor
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 24
            color: Qt.rgba(1, 1, 1, 0.045)
            border.width: 0.8
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Canvas {
                id: dotDisplay

                readonly property var glyphs: ({
                    "0": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
                    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
                    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
                    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
                    "4": ["10001", "10001", "10001", "11111", "00001", "00001", "00001"],
                    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
                    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
                    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
                    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
                    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
                    ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"]
                })
                property string displayText: root.displayTime
                property color activeColor: root.accentColor

                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 620)
                height: Math.min(parent.height - 30, 150)
                Accessible.name: root.displayTime

                onDisplayTextChanged: requestPaint()
                onActiveColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const context = getContext("2d");
                    context.clearRect(0, 0, width, height);
                    const cell = Math.min(width / (displayText.length * 6 - 1), height / 7);
                    const totalWidth = (displayText.length * 6 - 1) * cell;
                    const startX = (width - totalWidth) / 2;
                    const startY = (height - cell * 7) / 2;
                    const radius = cell * 0.27;
                    for (let charIndex = 0; charIndex < displayText.length; ++charIndex) {
                        const glyph = glyphs[displayText[charIndex]];
                        for (let row = 0; row < 7; ++row) {
                            for (let column = 0; column < 5; ++column) {
                                context.beginPath();
                                context.arc(startX + (charIndex * 6 + column + 0.5) * cell,
                                    startY + (row + 0.5) * cell, radius, 0, Math.PI * 2);
                                context.fillStyle = glyph[row][column] === "1"
                                    ? activeColor : Qt.rgba(1, 1, 1, 0.035);
                                context.fill();
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            RippleButton {
                implicitWidth: 148
                implicitHeight: 42
                buttonRadius: 21
                colBackground: Qt.rgba(0.42, 0.72, 0.96, 0.2)
                colBackgroundHover: Qt.rgba(0.42, 0.72, 0.96, 0.28)
                onClicked: TimerService.togglePomodoro()

                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: TimerService.pomodoroRunning ? Translation.tr("Pause")
                        : root.paused ? Translation.tr("Resume") : Translation.tr("Start")
                    color: Qt.rgba(0.86, 0.94, 1, 0.92)
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                }
            }

            RippleButton {
                implicitWidth: 94
                implicitHeight: 42
                enabled: TimerService.pomodoroRunning || root.paused
                buttonRadius: 21
                colBackground: Qt.rgba(1, 1, 1, 0.07)
                colBackgroundHover: Qt.rgba(1, 1, 1, 0.12)
                onClicked: TimerService.resetPomodoro()

                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Translation.tr("Reset")
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Repeater {
                model: [5, 15, 25, 60]

                delegate: RippleButton {
                    id: presetButton

                    required property int modelData
                    implicitWidth: 74
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: TimerService.focusTime === modelData * 60
                        ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.055)
                    colBackgroundHover: Qt.rgba(1, 1, 1, 0.12)
                    onClicked: TimerService.startPomodoroMinutes(modelData)

                    contentItem: StyledText {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr("%1 min").arg(presetButton.modelData)
                        color: Qt.rgba(1, 1, 1, 0.68)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
