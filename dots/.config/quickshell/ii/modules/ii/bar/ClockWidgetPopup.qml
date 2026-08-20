import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    required property bool compact
    property string formattedDate: Qt.locale().toString(DateTime.clock.date, "MMMM dd, dddd")
    property string formattedTime: DateTime.time
    property string formattedUptime: DateTime.uptime
    readonly property var pendingTodos: getPendingTodos(Todo.list)
    readonly property var visibleTodos: pendingTodos.slice(0, 3)
    readonly property int remainingTodoCount: Math.max(0, pendingTodos.length - visibleTodos.length)
    readonly property real dayProgress: getDayProgress()
    readonly property int dayProgressPercent: Math.floor(dayProgress * 100)
    stickyHover: true
    acceptsKeyboardFocus: true

    property bool stopwatchPaused: !TimerService.stopwatchRunning && TimerService.stopwatchTime > 0

    function getPendingTodos(todos) {
        return todos.map(function (item, index) {
            return Object.assign({}, item, {
                "originalIndex": index
            });
        }).filter(function (item) {
            return !item.done;
        });
    }

    function addTodo(description) {
        const text = description.trim()
        if (text.length === 0)
            return false;
        Todo.addTask(text)
        return true;
    }

    function formatTimerDisplay(seconds) {
        let m = Math.floor(seconds / 60);
        let s = seconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function formatStopwatchDisplay(centiseconds) {
        const totalSeconds = Math.floor(centiseconds / 100)
        const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, "0")
        const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, "0")
        const fraction = (Math.floor(centiseconds) % 100).toString().padStart(2, "0")
        return `${minutes}:${seconds}.${fraction}`
    }

    function timerLabel() {
        if (TimerService.pomodoroRunning)
            return Translation.tr("Pomodoro");
        if (TimerService.stopwatchTime > 0)
            return Translation.tr("Stopwatch");
        return Translation.tr("Timer");
    }

    function timerValue() {
        if (TimerService.pomodoroRunning)
            return root.formatTimerDisplay(TimerService.pomodoroSecondsLeft);
        if (TimerService.stopwatchTime > 0)
            return root.formatStopwatchDisplay(TimerService.stopwatchTime);
        return Translation.tr("Off");
    }

    function timerBadge() {
        if (root.stopwatchPaused)
            return Translation.tr("Paused");
        if (TimerService.pomodoroRunning)
            return TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus");
        return "";
    }

    function getDayProgress() {
        const date = DateTime.clock.date
        const secondsPassed = date.getHours() * 3600 + date.getMinutes() * 60 + date.getSeconds()

        return secondsPassed / 86400
    }

    contentItem: ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 12

        ExpressiveMetricCard {
            id: clockHero

            label: Translation.tr("Day progress")
            value: root.formattedTime
            supportingText: root.formattedDate
            badgeText: Translation.tr("%1% elapsed").arg(root.dayProgressPercent)
            badgeIcon: "clock_loader_60"
            icon: "schedule"
            progress: root.dayProgress
            shapeString: "Cookie9Sided"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            ExpressiveInfoTile {
                visible: !root.compact ? LocalSend.currentTransfer == null || LocalSend.droppedFiles.length > 0 : false
                label: Translation.tr("System uptime")
                value: root.formattedUptime
                icon: "computer"
                shapeString: "Clover4Leaf"
                containerColor: Appearance.colors.colSecondaryContainer
                shapeColor: Appearance.colors.colSecondary
                symbolColor: Appearance.colors.colOnSecondary
                textColor: Appearance.colors.colOnSecondaryContainer
                labelColor: Appearance.colors.colOnSecondaryContainer
            }

            ExpressiveInfoTile {
                visible: !root.compact ? LocalSend.currentTransfer == null || LocalSend.droppedFiles.length > 0 : false
                label: root.timerLabel()
                value: root.timerValue()
                badgeText: root.timerBadge()
                badgeIcon: root.stopwatchPaused ? "pause" : TimerService.pomodoroRunning ? "routine" : ""
                containerColor: TimerService.pomodoroBreak ? Appearance.colors.colTertiaryContainer : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer)
                shapeColor: TimerService.pomodoroBreak ? Appearance.colors.colTertiary : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colPrimary : Appearance.colors.colSecondary)
                symbolColor: TimerService.pomodoroBreak ? Appearance.colors.colOnTertiary : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondary)
                textColor: TimerService.pomodoroBreak ? Appearance.colors.colOnTertiaryContainer : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer)
                labelColor: textColor
                icon: TimerService.pomodoroBreak ? "coffee" : root.stopwatchPaused ? "timer_pause" : TimerService.stopwatchRunning ? "timer_play" : "timer"
                shapeString: TimerService.pomodoroRunning ? "Flower" : "SoftBurst"
            }

            LocalSendPill {
                visible: LocalSend.available
            }
        }

        Loader {
            Layout.fillWidth: true
            visible: active
            active: root.compact ? sourceComponent !== todoSection : true
            sourceComponent: LocalSend.currentTransfer !== null ? transferCard : LocalSend.droppedFiles.length > 0 ? sendCard : todoSection
        }

        Component {
            id: todoSection
            SectionCard {
                id: todoCard

                property bool composerOpen: false

                function openComposer() {
                    composerOpen = true
                    root.holdOpen = true
                    Qt.callLater(function() {
                        quickTodoInput.forceActiveFocus()
                        root.holdOpen = quickTodoInput.activeFocus
                    })
                }

                function closeComposer() {
                    quickTodoInput.clear()
                    quickTodoInput.focus = false
                    composerOpen = false
                    root.holdOpen = false
                }

                function submitTask() {
                    if (!root.addTodo(quickTodoInput.text))
                        return;
                    closeComposer()
                }

                title: Translation.tr("To-do")
                icon: "checklist"
                shapeString: "SoftBurst"
                shapeColor: Appearance.colors.colPrimaryContainer
                symbolColor: Appearance.colors.colOnPrimaryContainer
                headerExtraText: Translation.tr("%1 pending").arg(root.pendingTodos.length)

                RippleButton {
                    visible: !todoCard.composerOpen
                    Layout.alignment: Qt.AlignLeft
                    implicitWidth: addTaskContent.implicitWidth + 28
                    implicitHeight: 40
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    onClicked: todoCard.openComposer()

                    contentItem: Item {
                        id: addTaskContent

                        implicitWidth: addTaskRow.implicitWidth
                        implicitHeight: addTaskRow.implicitHeight

                        RowLayout {
                            id: addTaskRow
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                text: "add"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnPrimaryContainer
                                fill: 1
                            }

                            StyledText {
                                text: Translation.tr("Add task")
                                font.family: Appearance.font.family.title
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: todoCard.composerOpen
                    Layout.fillWidth: true
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialShape {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            implicitSize: 42
                            shapeString: "Puffy"
                            color: Appearance.colors.colTertiaryContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "edit_note"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnTertiaryContainer
                                fill: 1
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("New task")
                            font.family: Appearance.font.family.title
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSurface
                        }
                    }

                    MaterialTextArea {
                        id: quickTodoInput

                        Layout.fillWidth: true
                        Layout.preferredHeight: 112
                        placeholderText: Translation.tr("What needs to be done?")
                        selectByMouse: true
                        onActiveFocusChanged: root.holdOpen = activeFocus

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                todoCard.closeComposer()
                                event.accepted = true
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                    && (event.modifiers & Qt.ControlModifier)) {
                                todoCard.submitTask()
                                event.accepted = true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        spacing: 8

                        RippleButton {
                            implicitWidth: cancelContent.implicitWidth + 20
                            implicitHeight: 40
                            padding: 0
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSurfaceContainerHighest
                            colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                            onClicked: todoCard.closeComposer()

                            contentItem: Item {
                                id: cancelContent

                                implicitWidth: cancelRow.implicitWidth
                                implicitHeight: cancelRow.implicitHeight

                                RowLayout {
                                    id: cancelRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    MaterialSymbol {
                                        Layout.preferredWidth: 17
                                        text: "close"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: Appearance.colors.colOnSurface
                                    }

                                    StyledText {
                                        text: Translation.tr("Cancel")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnSurface
                                    }
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: createContent.implicitWidth + 20
                            implicitHeight: 40
                            padding: 0
                            enabled: quickTodoInput.text.trim().length > 0
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            colRipple: Appearance.colors.colPrimaryActive
                            onClicked: todoCard.submitTask()

                            contentItem: Item {
                                id: createContent

                                implicitWidth: createRow.implicitWidth
                                implicitHeight: createRow.implicitHeight

                                RowLayout {
                                    id: createRow
                                    anchors.centerIn: parent
                                    spacing: 3

                                    MaterialSymbol {
                                        Layout.preferredWidth: 17
                                        text: "check"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: Appearance.colors.colOnPrimary
                                        fill: 1
                                    }

                                    StyledText {
                                        text: Translation.tr("Create")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                LoadingPlaceholder {
                    Layout.preferredHeight: 30
                    visible: !todoCard.composerOpen && root.pendingTodos.length === 0
                    loading: false
                    emptyText: Translation.tr("No pending tasks")
                }

                Repeater {
                    model: todoCard.composerOpen ? [] : root.visibleTodos

                    delegate: ColumnLayout {
                        id: todoRow

                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            RippleButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colSecondaryContainer
                                colRipple: Appearance.colors.colSecondaryContainerActive
                                onClicked: Todo.markDone(todoRow.modelData.originalIndex)

                                contentItem: MaterialSymbol {
                                    text: "check_box_outline_blank"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    iconSize: Appearance.font.pixelSize.huge
                                    color: Appearance.colors.colPrimary
                                }

                                StyledToolTip {
                                    text: Translation.tr("Mark complete")
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: todoRow.modelData.content
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurface
                            }
                        }

                        Rectangle {
                            visible: todoRow.index < root.visibleTodos.length - 1
                            Layout.fillWidth: true
                            Layout.leftMargin: 38
                            implicitHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }
                    }
                }

                RowLayout {
                    visible: !todoCard.composerOpen && root.remainingTodoCount > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 38
                    spacing: 6

                    MaterialSymbol {
                        text: "more_horiz"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Translation.tr("%1 more tasks").arg(root.remainingTodoCount)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }

        Component {
            id: transferCard
            LocalSendTransferCard {}
        }

        Component {
            id: sendCard
            LocalSendSendCard {}
        }
    }
}
