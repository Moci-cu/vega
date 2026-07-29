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
    property alias searchInput: searchInput
    property string searchingText

    function selectedEntry() {
        const selectedIndex = Math.max(0, appResults.currentIndex);
        return LauncherSearch.results[selectedIndex];
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
            case SearchBar.SearchPrefixType.FileSearch: return "folder_search";
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
        placeholderText: Translation.tr("Search, calculate or run")
        implicitWidth: root.searchingText == "" ? Appearance.sizes.searchWidthCollapsed : Appearance.sizes.searchWidth

        Behavior on implicitWidth {
            id: searchWidthBehavior
            enabled: root.animateWidth
            NumberAnimation {
                duration: 300
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        onTextChanged: LauncherSearch.query = text

        onAccepted: {
            if (appResults.count > 0) {
                const selectedEntry = root.selectedEntry();
                if (!selectedEntry) return;
                GlobalStates.overviewOpen = false;
                selectedEntry.execute();
            }
        }

        Keys.onPressed: event => {
            const ctrlPressed = event.modifiers & Qt.ControlModifier;
            if (ctrlPressed && event.key === Qt.Key_N) {
                if (appResults.count > 0) {
                    appResults.currentIndex = Math.min(appResults.count - 1, appResults.currentIndex + 1);
                    appResults.positionViewAtIndex(appResults.currentIndex, ListView.Contain);
                }
                event.accepted = true;
                return;
            }
            if (ctrlPressed && event.key === Qt.Key_P) {
                if (appResults.count > 0) {
                    appResults.currentIndex = Math.max(0, appResults.currentIndex - 1);
                    appResults.positionViewAtIndex(appResults.currentIndex, ListView.Contain);
                }
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Tab) {
                if (LauncherSearch.results.length === 0) return;
                const tabbedText = LauncherSearch.results[0].name;
                LauncherSearch.query = tabbedText;
                searchInput.text = tabbedText;
                event.accepted = true;
            }
        }
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
