pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string filterText: ""
    property bool completedView: false
    readonly property int remainingCount: Todo.list.filter(task => !task.done).length
    readonly property int completedCount: Todo.list.filter(task => task.done).length
    readonly property var filteredTasks: {
        const needle = root.filterText.trim().toLowerCase();
        return Todo.list.map((task, index) => Object.assign({ originalIndex: index }, task))
            .filter(task => task.done === root.completedView
                && (!needle || String(task.content).toLowerCase().includes(needle)));
    }
    readonly property int taskCount: filteredTasks.length
    readonly property int currentIndex: taskList.currentIndex
    readonly property var selectedTask: currentIndex >= 0 ? filteredTasks[currentIndex] : null
    readonly property var selectedAction: {
        const task = root.selectedTask;
        if (!task) return null;
        const index = task.originalIndex;
        return {
            key: `todo-task:${index}`,
            name: task.done ? Translation.tr("Mark unfinished") : Translation.tr("Mark complete"),
            keepLauncherOpen: true,
            execute: () => root.toggleTask(index)
        };
    }

    function moveSelection(delta) {
        if (taskList.count <= 0) return;
        taskList.currentIndex = Math.max(0,
            Math.min(taskList.count - 1, Math.max(0, taskList.currentIndex) + delta));
        taskList.positionViewAtIndex(taskList.currentIndex, ListView.Contain);
    }

    function toggleTask(index) {
        if (Todo.list[index]?.done)
            Todo.markUnfinished(index);
        else
            Todo.markDone(index);
    }

    function addTask() {
        const description = taskInput.text.trim();
        if (!description) return;
        Todo.addTask(description);
        taskInput.clear();
        root.completedView = false;
    }

    onFilteredTasksChanged: Qt.callLater(() => {
        if (taskList.count <= 0)
            taskList.currentIndex = -1;
        else if (taskList.currentIndex < 0 || taskList.currentIndex >= taskList.count)
            taskList.currentIndex = 0;
    })

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(0.02, 0.025, 0.035, 0.16)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 14
                color: Qt.rgba(0.56, 0.74, 0.92, 0.12)
                border.width: 0.8
                border.color: Qt.rgba(0.82, 0.92, 1, 0.16)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "checklist"
                    iconSize: 24
                    color: Qt.rgba(0.72, 0.88, 1, 0.94)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: Translation.tr("To-Do")
                    color: Qt.rgba(1, 1, 1, 0.94)
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: Translation.tr("%1 remaining").arg(root.remainingCount)
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            RippleButton {
                implicitWidth: 116
                implicitHeight: 38
                buttonRadius: 19
                colBackground: Qt.rgba(0.42, 0.72, 0.96, 0.18)
                colBackgroundHover: Qt.rgba(0.42, 0.72, 0.96, 0.27)
                onClicked: taskInput.forceActiveFocus()

                contentItem: Item {
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: "add"
                            iconSize: 19
                            color: Qt.rgba(0.82, 0.92, 1, 0.94)
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: Translation.tr("New Task")
                            color: Qt.rgba(0.86, 0.94, 1, 0.94)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: tabRow.implicitWidth + 8
            implicitHeight: 38
            radius: 19
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 0.7
            border.color: Qt.rgba(1, 1, 1, 0.08)

            RowLayout {
                id: tabRow

                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: [
                        { label: Translation.tr("Active"), count: root.remainingCount, completed: false },
                        { label: Translation.tr("Completed"), count: root.completedCount, completed: true }
                    ]

                    delegate: RippleButton {
                        id: tabButton

                        required property var modelData
                        readonly property bool current: root.completedView === modelData.completed
                        implicitWidth: 124
                        implicitHeight: 32
                        buttonRadius: 16
                        rippleEnabled: false
                        colBackground: current ? Qt.rgba(1, 1, 1, 0.13) : "transparent"
                        colBackgroundHover: current ? Qt.rgba(1, 1, 1, 0.15)
                            : Qt.rgba(1, 1, 1, 0.07)
                        onClicked: root.completedView = modelData.completed

                        contentItem: StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: `${tabButton.modelData.label}  ${tabButton.modelData.count}`
                            color: Qt.rgba(1, 1, 1, tabButton.current ? 0.9 : 0.58)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: tabButton.current ? Font.Medium : Font.Normal
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 18
            color: Qt.rgba(1, 1, 1, 0.035)
            border.width: 0.7
            border.color: Qt.rgba(1, 1, 1, 0.08)

            ListView {
                id: taskList

                anchors.fill: parent
                anchors.margins: 8
                clip: true
                spacing: 3
                model: root.filteredTasks
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: count > 0 ? 0 : -1

                delegate: Rectangle {
                    id: taskItem

                    required property int index
                    required property var modelData
                    readonly property bool current: taskList.currentIndex === index
                    width: ListView.view.width
                    height: 52
                    radius: 15
                    color: current ? Qt.rgba(0.62, 0.78, 0.9, 0.13)
                        : taskHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: taskHover }
                    TapHandler { onTapped: taskList.currentIndex = taskItem.index }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 9
                        spacing: 11

                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            rippleEnabled: false
                            colBackground: taskItem.modelData.done
                                ? Qt.rgba(0.45, 0.84, 0.57, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                            colBackgroundHover: taskItem.modelData.done
                                ? Qt.rgba(0.45, 0.84, 0.57, 0.28) : Qt.rgba(1, 1, 1, 0.11)
                            onClicked: root.toggleTask(taskItem.modelData.originalIndex)

                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: taskItem.modelData.done ? "check" : "radio_button_unchecked"
                                iconSize: 20
                                color: taskItem.modelData.done
                                    ? Qt.rgba(0.58, 0.94, 0.68, 0.96) : Qt.rgba(1, 1, 1, 0.52)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: taskItem.modelData.content
                            textFormat: Text.PlainText
                            color: Qt.rgba(1, 1, 1, taskItem.modelData.done ? 0.48 : 0.88)
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.strikeout: taskItem.modelData.done
                            elide: Text.ElideRight
                        }

                        RippleButton {
                            visible: opacity > 0
                            opacity: taskHover.hovered || taskItem.current ? 1 : 0
                            implicitWidth: 34
                            implicitHeight: 34
                            buttonRadius: 17
                            rippleEnabled: false
                            colBackground: "transparent"
                            colBackgroundHover: Qt.rgba(0.95, 0.36, 0.4, 0.14)
                            onClicked: Todo.deleteItem(taskItem.modelData.originalIndex)

                            Behavior on opacity { NumberAnimation { duration: 100 } }

                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "delete_outline"
                                iconSize: 19
                                color: Qt.rgba(1, 0.55, 0.58, 0.82)
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: root.taskCount === 0
                spacing: 5

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.completedView ? "checklist" : "check_circle"
                    iconSize: 48
                    color: Qt.rgba(1, 1, 1, 0.28)
                }

                StyledText {
                    text: root.filterText.trim() ? Translation.tr("No matching tasks")
                        : root.completedView ? Translation.tr("Finished tasks will appear here")
                        : Translation.tr("Nothing left to do")
                    color: Qt.rgba(1, 1, 1, 0.42)
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 17
            color: Qt.rgba(1, 1, 1, 0.055)
            border.width: taskInput.activeFocus ? 1 : 0.7
            border.color: taskInput.activeFocus
                ? Qt.rgba(0.58, 0.8, 1, 0.42) : Qt.rgba(1, 1, 1, 0.09)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 7
                spacing: 8

                MaterialSymbol {
                    text: "add"
                    iconSize: 21
                    color: Qt.rgba(1, 1, 1, 0.48)
                }

                TextField {
                    id: taskInput

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 0
                    placeholderText: Translation.tr("Add a task…")
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                    color: Qt.rgba(1, 1, 1, 0.88)
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    renderType: Text.NativeRendering
                    background: null
                    onAccepted: root.addTask()
                }

                RippleButton {
                    id: addButton

                    implicitWidth: 68
                    implicitHeight: 36
                    enabled: taskInput.text.trim().length > 0
                    buttonRadius: 18
                    colBackground: Qt.rgba(0.42, 0.72, 0.96, 0.18)
                    colBackgroundHover: Qt.rgba(0.42, 0.72, 0.96, 0.27)
                    onClicked: root.addTask()

                    contentItem: StyledText {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr("Add")
                        color: Qt.rgba(0.86, 0.94, 1, addButton.enabled ? 0.94 : 0.34)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
