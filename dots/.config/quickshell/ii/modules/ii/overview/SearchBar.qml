pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RowLayout {
    id: root
    spacing: 6
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
    
    MaterialShapeWrappedMaterialSymbol {
        id: searchIcon
        Layout.alignment: Qt.AlignVCenter
        iconSize: Appearance.font.pixelSize.huge
        shape: switch(root.searchPrefixType) {
            case SearchBar.SearchPrefixType.Action: return MaterialShape.Shape.Pill;
            case SearchBar.SearchPrefixType.App: return MaterialShape.Shape.Clover4Leaf;
            case SearchBar.SearchPrefixType.Clipboard: return MaterialShape.Shape.Gem;
            case SearchBar.SearchPrefixType.Emojis: return MaterialShape.Shape.Sunny;
            case SearchBar.SearchPrefixType.Math: return MaterialShape.Shape.PuffyDiamond;
            case SearchBar.SearchPrefixType.ShellCommand: return MaterialShape.Shape.PixelCircle;
            case SearchBar.SearchPrefixType.WebSearch: return MaterialShape.Shape.SoftBurst;
            case SearchBar.SearchPrefixType.FileSearch: return MaterialShape.Shape.Cookie4Sided;
            case SearchBar.SearchPrefixType.Window: return MaterialShape.Shape.Cookie9Sided;
            default: return MaterialShape.Shape.Cookie7Sided;
        }
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
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 40
        focus: GlobalStates.overviewOpen
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colOnSurface
        placeholderTextColor: Appearance.colors.colOnSurfaceVariant
        placeholderText: Translation.tr("Search, calculate or run")
        implicitWidth: root.forceExpanded || root.searchingText != ""
            ? Appearance.sizes.searchWidth : Appearance.sizes.searchWidthCollapsed

        Behavior on implicitWidth {
            id: searchWidthBehavior
            enabled: root.animateWidth
            NumberAnimation {
                duration: 300
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
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
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        onClicked: {
            GlobalStates.overviewOpen = false;
            const overviewAnimationEnabled = Config.options.overview.showOpeningAnimation

            if (!overviewAnimationEnabled) {
                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "search"]);
                return
            }
            lensDelayTimer.start();
        }
        text: "image_search"
        StyledToolTip {
            text: Translation.tr("Google Lens")
            y: parent.height + 3
        }
    }

    Timer {
        id: lensDelayTimer
        interval: 201
        onTriggered: {
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "search"]);
        }
    }

    IconToolbarButton {
        id: songRecButton
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        Layout.rightMargin: 4
        toggled: SongRec.running
        onClicked: SongRec.toggleRunning()
        text: "music_cast"

        StyledToolTip {
            text: Translation.tr("Recognize music")
            y: parent.height + 3
        }

        colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
        background: MaterialShape {
            RotationAnimation on rotation {
                running: songRecButton.toggled
                duration: 12000
                easing.type: Easing.Linear
                loops: Animation.Infinite
                from: 0
                to: 360
            }
            shape: {
                if (songRecButton.down) {
                    return songRecButton.toggled ? MaterialShape.Shape.Circle : MaterialShape.Shape.Square
                } else {
                    return songRecButton.toggled ? MaterialShape.Shape.SoftBurst : MaterialShape.Shape.Circle
                }
            }
            color: {
                if (songRecButton.toggled) {
                    return songRecButton.hovered ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary
                } else {
                    return songRecButton.hovered ? Appearance.colors.colSurfaceContainerHigh : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh)
                }
            }
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }
}
