import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // These are keybinds for stopwatch and pomodoro
    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) { // Switch tabs
            swipeView.currentIndex = event.key === Qt.Key_PageDown ? 1 : 0;
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) { // Pause/resume with Space or S
            if (swipeView.currentIndex === 0) {
                TimerService.togglePomodoro()
            } else {
                TimerService.toggleStopwatch()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_R) { // Reset with R
            if (swipeView.currentIndex === 0) {
                TimerService.resetPomodoro()
            } else {
                TimerService.stopwatchReset()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_L) { // Record lap with L
            TimerService.stopwatchRecordLap()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ButtonGroup {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.topMargin: 6
            spacing: 4
            uniformCellSizes: true

            SelectionGroupButton {
                Layout.fillWidth: true
                leftmost: true
                toggled: swipeView.currentIndex === 0
                buttonText: Translation.tr("Pomodoro")
                buttonIcon: "search_activity"
                onClicked: swipeView.currentIndex = 0
            }

            SelectionGroupButton {
                Layout.fillWidth: true
                rightmost: true
                toggled: swipeView.currentIndex === 1
                buttonText: Translation.tr("Stopwatch")
                buttonIcon: "timer"
                onClicked: swipeView.currentIndex = 1
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 4
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true

            // Tabs
            PomodoroTimer {}
            Stopwatch {}
        }
    }
}
