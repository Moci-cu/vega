pragma ComponentBehavior: Bound

import Qt.labs.synchronizer
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Wrapper
    id: root

    readonly property string xdgConfigHome: Directories.config
    readonly property int typingDebounceInterval: 35
    readonly property int typingResultLimit: 15 // Should be enough to cover the whole view
    readonly property var screen: root.QsWindow.window?.screen

    readonly property bool sharpMode: Config.options.appearance.sharpMode
    readonly property bool backdropReady: liquidGlassCapture.hasContent || backdropCaptureTimedOut
    property string searchingText: LauncherSearch.query
    property bool showResults: searchingText != ""
    property bool backdropCaptureTimedOut: false
    implicitWidth: searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchWidgetContent.implicitHeight + searchBar.verticalPadding * 2 + Appearance.sizes.elevationMargin * 2

    function focusFirstItem() {
        if (appResults.count <= 0)
            return;
        if (appResults.currentIndex !== 0)
            appResults.currentIndex = 0;
    }

    function focusSearchInput() {
        searchBar.forceFocus();
    }

    function disableExpandAnimation() {
        searchBar.animateWidth = false;
    }

    function cancelSearch() {
        searchBar.cancelPendingQuery();
        searchBar.searchInput.selectAll();
        LauncherSearch.query = "";
        searchBar.animateWidth = true;
    }

    function setSearchingText(text) {
        searchBar.setQueryImmediately(text);
    }

    Keys.onPressed: event => {
        // Prevent Esc and Backspace from registering
        if (event.key === Qt.Key_Escape)
            return;

        // Handle Backspace: focus and delete character if not focused
        if (event.key === Qt.Key_Backspace) {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                if (event.modifiers & Qt.ControlModifier) {
                    // Delete word before cursor
                    let text = searchBar.searchInput.text;
                    let pos = searchBar.searchInput.cursorPosition;
                    if (pos > 0) {
                        // Find the start of the previous word
                        let left = text.slice(0, pos);
                        let match = left.match(/(\s*\S+)\s*$/);
                        let deleteLen = match ? match[0].length : 1;
                        searchBar.searchInput.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                        searchBar.searchInput.cursorPosition = pos - deleteLen;
                    }
                } else {
                    // Delete character before cursor if any
                    if (searchBar.searchInput.cursorPosition > 0) {
                        searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition - 1) + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                        searchBar.searchInput.cursorPosition -= 1;
                    }
                }
                // Always move cursor to end after programmatic edit
                searchBar.searchInput.cursorPosition = searchBar.searchInput.text.length;
                event.accepted = true;
            }
            // If already focused, let TextField handle it
            return;
        }

        // Only handle visible printable characters (ignore control chars, arrows, etc.)
        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) // ignore control chars like Backspace, Tab, etc.
        {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                // Insert the character at the cursor position
                searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition) + event.text + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                searchBar.searchInput.cursorPosition += 1;
                event.accepted = true;
                root.focusFirstItem();
            }
        }
    }

    ScreencopyView {
        id: liquidGlassCapture
        width: Math.max(1, root.screen?.width ?? 1)
        height: Math.max(1, root.screen?.height ?? 1)
        captureSource: GlobalStates.overviewOpen && !root.backdropCaptureTimedOut ? root.screen : null
        live: false
        paintCursor: false

        onHasContentChanged: {
            if (hasContent)
                liquidGlassBackdrop.scheduleUpdate();
        }
    }

    ShaderEffectSource {
        id: liquidGlassBackdrop
        visible: false
        width: liquidGlassCapture.width
        height: liquidGlassCapture.height
        sourceItem: liquidGlassCapture
        sourceRect: Qt.rect(0, 0, width, height)
        textureSize: Qt.size(
            Math.ceil(width * (root.screen?.devicePixelRatio ?? 1)),
            Math.ceil(height * (root.screen?.devicePixelRatio ?? 1))
        )
        hideSource: true
        live: false
    }

    Connections {
        target: GlobalStates

        function onOverviewOpenChanged() {
            root.backdropCaptureTimedOut = false;
        }
    }

    Timer {
        interval: 200
        running: GlobalStates.overviewOpen && !liquidGlassCapture.hasContent
        onTriggered: root.backdropCaptureTimedOut = true
    }

    Item { // Background
        id: searchWidgetContent
        clip: true
        implicitWidth: gridLayout.implicitWidth
        implicitHeight: gridLayout.implicitHeight
        property real radius: Config.options.appearance.sharpMode ? 0 : searchBar.height / 2 + searchBar.verticalPadding

        Behavior on implicitHeight {
            id: searchHeightBehavior
            enabled: GlobalStates.overviewOpen && root.showResults
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        LiquidGlassSurface {
            id: liquidGlassSurface
            anchors.fill: parent
            shown: GlobalStates.overviewOpen
            wallpaperSource: liquidGlassBackdrop
            sourceReady: liquidGlassCapture.hasContent
            sourceFillsItem: true
            enhancedOptics: true
            itemSourceRect: Qt.rect(
                ((root.screen?.width ?? root.width) - root.width) / 2 / liquidGlassBackdrop.width,
                (screenY - (!Config.options.bar.vertical && !Config.options.bar.bottom ? Appearance.sizes.barHeight : 0)) / liquidGlassBackdrop.height,
                width / liquidGlassBackdrop.width,
                height / liquidGlassBackdrop.height
            )
            screen: root.screen
            tintColor: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.62)
            radius: searchWidgetContent.radius
        }

        GridLayout {
            id: gridLayout
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 1

            // clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: searchWidgetContent.width
                    height: searchWidgetContent.width
                    radius: searchWidgetContent.radius
                }
            }

            SearchBar {
                id: searchBar
                property real verticalPadding: 4
                debounceInterval: root.typingDebounceInterval
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                Layout.topMargin: verticalPadding
                Layout.bottomMargin: verticalPadding
                Synchronizer on searchingText {
                    property alias source: root.searchingText
                }
            }

            Rectangle {
                // Separator
                visible: root.showResults
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutlineVariant
                Layout.row: 1
            }

            ListView { // App results
                id: appResults
                visible: root.showResults
                Layout.fillWidth: true
                implicitHeight: Math.min(600, appResults.contentHeight + topMargin + bottomMargin)
                clip: true
                topMargin: 10
                bottomMargin: 10
                spacing: 2
                KeyNavigation.up: searchBar
                highlightMoveDuration: 100

                function setResultValues(values) {
                    const limitedValues = (values ?? []).slice(0, root.typingResultLimit);
                    resultModel.values = limitedValues;
                    if (limitedValues.length > 0 && appResults.currentIndex !== 0) {
                        Qt.callLater(root.focusFirstItem);
                    }
                }

                onFocusChanged: {
                    if (focus)
                        root.focusFirstItem();
                }

                Connections {
                    target: LauncherSearch
                    function onResultsChanged() {
                        appResults.setResultValues(LauncherSearch.results);
                    }
                }

                model: ScriptModel {
                    id: resultModel
                    objectProp: "key"
                }

                delegate: SearchItem {
                    id: searchItem
                    // The selectable item for each search result
                    required property int index
                    required property var modelData
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    entry: modelData
                    query: {
                        const prefix = LauncherSearch.matchedPrefix(root.searchingText)
                        return prefix ? StringUtils.cleanPrefix(root.searchingText, prefix) : root.searchingText
                    }
                    current: appResults.currentIndex === index

                    onHoveredChanged: {
                        if (hovered && appResults.currentIndex !== index)
                            appResults.currentIndex = index;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            if (LauncherSearch.results.length === 0)
                                return;
                            const tabbedText = searchItem.modelData.name;
                            searchBar.setQueryImmediately(tabbedText);
                            event.accepted = true;
                            root.focusSearchInput();
                        }
                    }
                }
            }
        }
    }
}
