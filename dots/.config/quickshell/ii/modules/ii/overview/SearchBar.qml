pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    spacing: 8
    property bool animateWidth: false
    property bool forceExpanded: false
    property alias searchInput: searchInput
    property string searchingText
    property int debounceInterval: 35
    property int resultCount: 0
    property int currentIndex: -1
    property int navigationColumns: 1
    property var resultAt: index => LauncherSearch.results[index]
    property var executeResult: entry => LauncherSearch.executeResult(entry)
    property var moveSelection: (delta, linear) => {}

    function cancelPendingQuery() {
        queryCommitTimer.stop();
    }

    function flushPendingQuery() {
        queryCommitTimer.stop();
        LauncherSearch.query = searchInput.text;
    }

    function setQueryImmediately(text) {
        searchInput.text = text;
        queryCommitTimer.stop();
        LauncherSearch.query = text;
    }

    function selectedEntry() {
        const selectedIndex = Math.max(0, root.currentIndex);
        return root.resultAt(selectedIndex);
    }

    function forceFocus() {
        searchInput.forceActiveFocus();
    }

    enum SearchPrefixType { Action, App, Clipboard, Emojis, Math, ShellCommand, WebSearch, FileSearch, Window, DefaultSearch }

    property var searchPrefixType: {
        switch (LauncherSearch.matchedPrefixName(root.searchingText)) {
        case "action": return SearchBar.SearchPrefixType.Action;
        case "app": return SearchBar.SearchPrefixType.App;
        case "clipboard": return SearchBar.SearchPrefixType.Clipboard;
        case "emojis": return SearchBar.SearchPrefixType.Emojis;
        case "math": return SearchBar.SearchPrefixType.Math;
        case "shellCommand": return SearchBar.SearchPrefixType.ShellCommand;
        case "webSearch": return SearchBar.SearchPrefixType.WebSearch;
        case "fileSearch": return SearchBar.SearchPrefixType.FileSearch;
        case "window": return SearchBar.SearchPrefixType.Window;
        default: return SearchBar.SearchPrefixType.DefaultSearch;
        }
    }
    
    MaterialSymbol {
        id: searchIcon
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 4
        iconSize: 25
        color: Qt.rgba(1, 1, 1, 0.72)
        text: switch (root.searchPrefixType) {
            case SearchBar.SearchPrefixType.Action: return "settings_suggest";
            case SearchBar.SearchPrefixType.App: return "apps";
            case SearchBar.SearchPrefixType.Clipboard: return "content_paste_search";
            case SearchBar.SearchPrefixType.Emojis: return "add_reaction";
            case SearchBar.SearchPrefixType.Math: return "calculate";
            case SearchBar.SearchPrefixType.ShellCommand: return "terminal";
            case SearchBar.SearchPrefixType.WebSearch: return "travel_explore";
            case SearchBar.SearchPrefixType.FileSearch: return "folder";
            case SearchBar.SearchPrefixType.Window: return "select_window";
            case SearchBar.SearchPrefixType.DefaultSearch: return "search";
            default: return "search";
        }
    }
    ToolbarTextField { // Search box
        id: searchInput
        Layout.fillWidth: true
        implicitHeight: 46
        focus: GlobalStates.overviewOpen
        padding: 0
        font.pixelSize: Appearance.font.pixelSize.normal
        color: Qt.rgba(1, 1, 1, 0.9)
        placeholderTextColor: Qt.rgba(1, 1, 1, 0.58)
        placeholderText: Translation.tr("Search or Ask")
        colBackground: "transparent"
        renderType: Text.QtRendering

        cursorDelegate: Item {
            width: 3
            height: searchInput.font.pixelSize + 8

            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: parent.height
                radius: 3.5
                color: Qt.rgba(0.48, 0.78, 1, 0.2)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 2.2
                height: parent.height
                radius: 1.1
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(0.78, 0.9, 1, 0.72)
                    }
                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 1)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(0.68, 0.86, 1, 0.72)
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 0.7
                height: parent.height - 2
                radius: 0.35
                color: Qt.rgba(1, 1, 1, 0.94)
            }
        }

        onTextChanged: {
            queryCommitTimer.pendingQuery = text;
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
                const tabbedText = root.resultAt(0)?.name ?? "";
                root.setQueryImmediately(tabbedText);
                event.accepted = true;
            }
        }
    }

    Timer {
        id: queryCommitTimer
        property string pendingQuery: ""
        interval: root.debounceInterval
        onTriggered: LauncherSearch.query = pendingQuery
    }

    IconToolbarButton {
        id: moreActionsButton

        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        Layout.rightMargin: 2
        text: "more_horiz"
        colText: Qt.rgba(1, 1, 1, 0.68)
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
