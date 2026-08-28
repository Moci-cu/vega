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
    property var autocompleteWallpaperSource
    property bool autocompleteSourceReady: false
    property var autocompleteSourceRectFor: item => Qt.rect(0, 0, 1, 1)
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
        const entry = root.autocompleteEntry;
        if (!entry)
            return "";
        if (root.autocompleteIsApp)
            return Translation.tr("Open");
        return String(entry.verb ?? "");
    }
    readonly property string autocompleteInputQuery: LauncherSearch.nativeAppQuery(searchInput.text).trim()
    readonly property string autocompleteName: String(root.autocompleteEntry?.name ?? "")
    readonly property bool autocompleteMatchesInput: root.autocompleteInputQuery.length > 0
        && root.autocompleteName.toLowerCase().startsWith(root.autocompleteInputQuery.toLowerCase())
    readonly property string autocompleteCompletion: {
        return root.autocompleteMatchesInput
            ? root.autocompleteName.slice(root.autocompleteInputQuery.length) : "";
    }

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
        return root.selectedResult ?? root.resultAt(selectedIndex);
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
            height: searchInput.font.pixelSize + 6
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
                wallpaperSource: root.autocompleteWallpaperSource
                sourceReady: root.autocompleteSourceReady
                sourceFillsItem: true
                enhancedOptics: true
                thicknessOverride: 0.06
                edgeLighting: 0.34
                refraction: 0
                itemSourceRect: root.autocompleteSourceRectFor(autocompleteGlass)
                screen: root.autocompleteScreen
                tintColor: Qt.rgba(0.86, 0.9, 0.94, 0.12)
                radius: 4
            }

            RowLayout {
                id: autocompleteContent

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                StyledText {
                    visible: root.autocompleteCompletion.length > 0
                    text: root.autocompleteCompletion
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
