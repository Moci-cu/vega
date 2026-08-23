import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int currentTab: 0
    property var tabButtonList: [
        {"name": Translation.tr("Pomodoro"), "icon": "search_activity"},
        {"name": Translation.tr("Stopwatch"), "icon": "timer"}
    ]

    // These are keybinds for stopwatch and pomodoro
    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) { // Switch tabs
            root.currentTab = event.key === Qt.Key_PageDown ? 1 : 0;
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) { // Pause/resume with Space or S
            if (root.currentTab === 0) {
                TimerService.togglePomodoro()
            } else {
                TimerService.toggleStopwatch()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_R) { // Reset with R
            if (root.currentTab === 0) {
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
                toggled: root.currentTab === 0
                buttonText: root.tabButtonList[0].name
                buttonIcon: root.tabButtonList[0].icon
                onClicked: root.currentTab = 0
            }

            SelectionGroupButton {
                Layout.fillWidth: true
                rightmost: true
                toggled: root.currentTab === 1
                buttonText: root.tabButtonList[1].name
                buttonIcon: root.tabButtonList[1].icon
                onClicked: root.currentTab = 1
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 4
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: root.currentTab
            onCurrentIndexChanged: root.currentTab = currentIndex

            // Tabs
            PomodoroTimer {}
            Stopwatch {}
        }
    }
}
