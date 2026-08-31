pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    spacing: 8
    property bool animateWidth: false
    property bool forceExpanded: false
    property string queryPrefix: ""
    property string inputPlaceholder: Translation.tr("Search or Ask")
    property string leadingIcon: ""
    property bool calculatorActive: false
    property alias searchInput: searchInput
    property string searchingText
    property int debounceInterval: 35
    property int resultCount: 0
    property int currentIndex: -1
    property int navigationColumns: 1
    property var selectedResult
    property var resultAt: index => LauncherSearch.results[index]
    property var executeResult: entry => LauncherSearch.executeResult(entry)
    property var moveSelection: (delta, linear) => {}
    property var autocompleteScreen
    property bool caretBlinkOn: true
    readonly property var autocompleteEntry: {
        const query = root.searchingText.trim();
        const count = root.resultCount;
        const index = root.currentIndex;
        return query.length > 0 && count > 0
            ? (root.selectedResult ?? root.resultAt(Math.max(0, index))) : null;
    }
    readonly property bool autocompleteIsApp: root.autocompleteEntry?.nativeApp
        || String(root.autocompleteEntry?.key ?? "").startsWith("app:")
    readonly property string autocompleteAction: {
        if (root.calculatorActive)
            return "";
        const entry = root.autocompleteEntry;
        if (!entry)
            return "";
        if (root.autocompleteIsApp)
            return Translation.tr("Open");
        return String(entry.verb ?? "");
    }
    readonly property string autocompleteInputQuery: LauncherSearch.nativeAppQuery(searchInput.text).trim()
    readonly property string autocompleteName: String(root.autocompleteEntry?.name ?? "")
    readonly property bool autocompleteMatchesInput: root.calculatorActive
        || (root.autocompleteInputQuery.length > 0
            && root.autocompleteName.toLowerCase().startsWith(root.autocompleteInputQuery.toLowerCase()))
    readonly property string autocompleteCompletion: {
        if (root.calculatorActive)
            return "";
        return root.autocompleteMatchesInput
            ? root.autocompleteName.slice(root.autocompleteInputQuery.length) : "";
    }

    function cancelPendingQuery() {
        queryCommitTimer.stop();
    }

    function flushPendingQuery() {
        queryCommitTimer.stop();
        LauncherSearch.query = root.queryPrefix + searchInput.text;
    }

    function setQueryImmediately(text) {
        const query = String(text ?? "");
        searchInput.text = root.queryPrefix && query.startsWith(root.queryPrefix)
            ? query.slice(root.queryPrefix.length) : query;
        queryCommitTimer.stop();
        LauncherSearch.query = root.queryPrefix + searchInput.text;
    }

    function selectedEntry() {
        const selectedIndex = Math.max(0, root.currentIndex);
        return root.selectedResult ?? root.resultAt(selectedIndex);
    }

    function forceFocus() {
        searchInput.forceActiveFocus();
    }

    MaterialSymbol {
        visible: root.leadingIcon.length > 0
        Layout.preferredWidth: 26
        Layout.alignment: Qt.AlignVCenter
        text: root.leadingIcon
        iconSize: 24
        color: Qt.rgba(1, 1, 1, 0.72)
    }

    ToolbarTextField { // Search box
        id: searchInput
        Layout.fillWidth: true
        implicitHeight: 46
        focus: GlobalStates.overviewOpen
        padding: 0
        font.pixelSize: Appearance.font.pixelSize.larger
        color: Qt.rgba(1, 1, 1, 0.9)
        placeholderTextColor: Qt.rgba(1, 1, 1, 0.58)
        placeholderText: root.inputPlaceholder
        colBackground: "transparent"
        renderType: Text.QtRendering

        cursorDelegate: Item {
            width: 3
            height: searchInput.font.pixelSize + 4
            opacity: searchInput.activeFocus && !autocompleteChip.visible && root.caretBlinkOn ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.InOutSine
                }
            }

            RectangularShadow {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2
                height: parent.height / 2 + 2
                radius: 1
                blur: 8
                spread: 1
                color: Qt.rgba(0.42, 0.8, 1, 0.72)
                cached: true
            }

            RectangularShadow {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2
                height: parent.height / 2 + 2
                radius: 1
                blur: 8
                spread: 1
                color: Qt.rgba(1, 0.68, 0.3, 0.68)
                cached: true
            }

            Rectangle {
                anchors.centerIn: parent
                width: 2
                height: parent.height
                radius: 1
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(0.82, 0.94, 1, 1)
                    }
                    GradientStop {
                        position: 0.42
                        color: Qt.rgba(1, 1, 1, 1)
                    }
                    GradientStop {
                        position: 0.58
                        color: Qt.rgba(1, 1, 1, 1)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(1, 0.9, 0.72, 1)
                    }
                }
            }
        }

        Item {
            id: autocompleteChip

            readonly property real desiredX: Math.max(0, searchInput.cursorRectangle.x)

            x: desiredX
            anchors.verticalCenter: parent.verticalCenter
            width: autocompleteContent.implicitWidth + 4
            height: autocompleteContent.implicitHeight + 6
            z: 5
            visible: root.autocompleteAction.length > 0
                && root.autocompleteMatchesInput
                && searchInput.text.length > 0
                && searchInput.cursorPosition === searchInput.text.length
                && desiredX + width <= searchInput.width - 4

            LiquidGlassSurface {
                id: autocompleteGlass

                anchors.fill: parent
                shown: autocompleteChip.visible
                compositorBackdrop: true
                thicknessOverride: 0.06
                edgeLighting: 0.34
                screen: root.autocompleteScreen
                tintColor: Qt.rgba(0.86, 0.9, 0.94, 0.12)
                radius: 10
            }

            RowLayout {
                id: autocompleteContent

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                StyledText {
                    visible: root.autocompleteCompletion.length > 0
                    text: root.autocompleteCompletion.replace(/^ /, "\u00a0")
                    color: Qt.rgba(1, 1, 1, 0.86)
                    font: searchInput.font
                }

                StyledText {
                    text: `— ${root.autocompleteAction}`
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font: searchInput.font
                }
            }
        }

        onTextChanged: {
            root.caretBlinkOn = true;
            queryCommitTimer.pendingQuery = root.queryPrefix + text;
            queryCommitTimer.restart();
        }

        onAccepted: {
            root.flushPendingQuery();
            if (root.resultCount > 0) {
                const selectedEntry = root.selectedEntry();
                if (!selectedEntry) return;
                GlobalStates.overviewOpen = false;
                root.executeResult(selectedEntry);
            }
        }

        Keys.onPressed: event => {
            const ctrlPressed = event.modifiers & Qt.ControlModifier;
            if (ctrlPressed && event.key === Qt.Key_N) {
                root.moveSelection(1, true);
                event.accepted = true;
                return;
            }
            if (ctrlPressed && event.key === Qt.Key_P) {
                root.moveSelection(-1, true);
                event.accepted = true;
                return;
            }
            let selectionDelta = 0;
            if (root.navigationColumns > 1 && event.key === Qt.Key_Left)
                selectionDelta = -1;
            else if (root.navigationColumns > 1 && event.key === Qt.Key_Right)
                selectionDelta = 1;
            else if (event.key === Qt.Key_Up)
                selectionDelta = -root.navigationColumns;
            else if (event.key === Qt.Key_Down)
                selectionDelta = root.navigationColumns;
            if (selectionDelta !== 0 && root.resultCount > 0) {
                root.moveSelection(selectionDelta);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Tab) {
                root.flushPendingQuery();
                if (root.resultCount === 0) return;
                const tabbedText = root.selectedEntry()?.name ?? "";
                root.setQueryImmediately(tabbedText);
                event.accepted = true;
            }
        }
    }

    IconImage {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        visible: root.autocompleteIsApp && root.autocompleteAction.length > 0
            && root.autocompleteMatchesInput
        source: AppSearch.iconPath(root.autocompleteEntry?.iconName ?? "", "image-missing")
        asynchronous: true
    }

    Timer {
        id: queryCommitTimer
        property string pendingQuery: ""
        interval: root.debounceInterval
        onTriggered: LauncherSearch.query = pendingQuery
    }

    Timer {
        interval: 650
        repeat: true
        running: searchInput.activeFocus && !autocompleteChip.visible
        onRunningChanged: root.caretBlinkOn = true
        onTriggered: root.caretBlinkOn = !root.caretBlinkOn
    }

    IconToolbarButton {
        id: moreActionsButton

        visible: !root.calculatorActive
        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        Layout.rightMargin: 2
        text: "more_horiz"
        colText: Qt.rgba(1, 1, 1, 0.46)
        onClicked: moreActionsMenu.open()

        Menu {
            id: moreActionsMenu

            x: moreActionsButton.width - width
            y: moreActionsButton.height + 4

            MenuItem {
                text: Translation.tr("Google Lens")
                onTriggered: {
                    GlobalStates.overviewOpen = false;
                    if (!Config.options.overview.showOpeningAnimation) {
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "search"]);
                        return;
                    }
                    lensDelayTimer.start();
                }
            }

            MenuItem {
                text: SongRec.running ? Translation.tr("Stop recognizing music") : Translation.tr("Recognize music")
                onTriggered: SongRec.toggleRunning()
            }
        }
    }

    Timer {
        id: lensDelayTimer
        interval: 201
        onTriggered: {
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "search"]);
        }
    }

}
