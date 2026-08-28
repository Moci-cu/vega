pragma ComponentBehavior: Bound

import Qt.labs.synchronizer
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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
    readonly property int typingResultLimit: 7
    readonly property int appGridColumns: 5
    readonly property int appGridRows: 4
    readonly property int appGridCapacity: appGridColumns * appGridRows
    readonly property real appGridCellWidth: 100
    readonly property real appGridCellHeight: 104
    readonly property real resultsViewportWidth: appGridColumns * appGridCellWidth
    readonly property real resultsViewportHeight: appGridRows * appGridCellHeight
    readonly property var screen: root.QsWindow.window?.screen ?? null

    readonly property bool sharpMode: Config.options.appearance.sharpMode
    readonly property bool backdropReady: (liquidGlassPipeline.item?.ready ?? false) || backdropCaptureTimedOut
    readonly property bool appMode: LauncherSearch.isApplicationQuery(root.searchingText)
    readonly property bool nativeAppSearchActive: LauncherSearch.shouldUseNativeAppSearch(root.searchingText)
    readonly property int activeResultCount: appMode ? appGrid.count : listResults.count
    readonly property int activeCurrentIndex: appMode ? appGrid.currentIndex : listResults.currentIndex
    property string searchingText: LauncherSearch.query
    readonly property bool showResults: GlobalStates.overviewOpen
    property bool backdropCaptureTimedOut: false
    property real retainedBackdropWidth: 1
    property real retainedBackdropHeight: 1
    implicitWidth: searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchWidgetContent.implicitHeight + searchBar.verticalPadding * 2 + Appearance.sizes.elevationMargin * 2

    function retainBackdropSize(targetWidth, targetHeight) {
        if (!GlobalStates.overviewOpen)
            return;
        root.retainedBackdropWidth = Math.max(root.retainedBackdropWidth, targetWidth + 4);
        root.retainedBackdropHeight = Math.max(root.retainedBackdropHeight, targetHeight + 4);
    }

    function focusFirstItem() {
        const view = root.appMode ? appGrid : listResults;
        if (view.count <= 0)
            return;
        if (view.currentIndex !== 0)
            view.currentIndex = 0;
        view.positionViewAtIndex(0, root.appMode ? GridView.Contain : ListView.Contain);
    }

    function moveSelection(delta, linear = false) {
        const view = root.appMode ? appGrid : listResults;
        if (view.count <= 0)
            return;
        const current = Math.max(0, view.currentIndex);
        if (root.appMode && !linear) {
            const column = current % root.appGridColumns;
            if ((delta === -1 && column === 0) || (delta === 1 && column === root.appGridColumns - 1))
                return;
            if (Math.abs(delta) === root.appGridColumns
                    && (current + delta < 0 || current + delta >= view.count))
                return;
        }
        view.currentIndex = Math.max(0, Math.min(view.count - 1, current + delta));
        view.positionViewAtIndex(view.currentIndex, root.appMode ? GridView.Contain : ListView.Contain);
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

    function resultAt(index) {
        return root.nativeAppSearchActive ? NativeAppSearch.get(index) : resultModel.values[index];
    }

    function refreshResults() {
        const values = LauncherSearch.results;
        if (root.appMode) {
            const query = LauncherSearch.nativeAppQuery(root.searchingText);
            const blankQuery = query.trim().length === 0;
            const limit = blankQuery ? Math.max(root.appGridCapacity, AppSearch.list.length) : root.appGridCapacity;
            if (root.nativeAppSearchActive) {
                NativeAppSearch.search(query, limit);
                return;
            }
            NativeAppSearch.clear();
            resultModel.values = blankQuery
                ? Array.from(AppSearch.list)
                    .sort((left, right) => String(left.name).localeCompare(String(right.name)))
                    .map(entry => LauncherSearch.appResult(entry))
                : (values ?? []).filter(entry => String(entry?.key ?? "").startsWith("app:")).slice(0, limit);
            Qt.callLater(root.focusFirstItem);
            return;
        }
        NativeAppSearch.clear();
        resultModel.values = (values ?? []).slice(0, root.typingResultLimit);
        Qt.callLater(root.focusFirstItem);
    }

    function scheduleResultsRefresh() {
        resultsRefreshTimer.restart();
    }

    onSearchingTextChanged: root.scheduleResultsRefresh()
    onAppModeChanged: root.scheduleResultsRefresh()
    onNativeAppSearchActiveChanged: root.scheduleResultsRefresh()
    Component.onCompleted: root.scheduleResultsRefresh()

    Timer {
        id: resultsRefreshTimer
        interval: 0
        onTriggered: root.refreshResults()
    }

    Connections {
        target: NativeAppSearch

        function onAvailableChanged() {
            root.scheduleResultsRefresh();
        }
    }

    Connections {
        target: NativeAppSearch.model
        ignoreUnknownSignals: true

        function onSearchFinished() {
            Qt.callLater(root.focusFirstItem);
        }
    }

    Connections {
        target: LauncherSearch

        function onResultsChanged() {
            root.scheduleResultsRefresh();
        }
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

    component AppGridItem: RippleButton {
        id: gridItem

        required property int index
        required property var modelData

        width: root.appGridCellWidth
        height: root.appGridCellHeight
        toggled: appGrid.currentIndex === index
        buttonRadius: Appearance.rounding.normal
        colBackground: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 1)
        colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
        colBackgroundToggled: Appearance.colors.colPrimaryContainer
        colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
        colRipple: Appearance.colors.colSurfaceContainerHighest
        colRippleToggled: Appearance.colors.colPrimaryContainerActive

        background {
            anchors.margins: 4
        }

        onHoveredChanged: {
            if (hovered && appGrid.currentIndex !== index)
                appGrid.currentIndex = index;
        }
        onClicked: {
            GlobalStates.overviewOpen = false;
            LauncherSearch.executeResult(gridItem.modelData);
        }

        contentItem: Item {
            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(1, parent.width - 12)
                spacing: 6

                IconImage {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    source: AppSearch.iconPath(gridItem.modelData?.iconName ?? "", "image-missing")
                    asynchronous: true
                }

                StyledText {
                    Layout.fillWidth: true
                    color: gridItem.toggled
                        ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.small
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    text: gridItem.modelData?.name ?? ""
                }
            }
        }
    }

    Loader {
        id: liquidGlassPipeline
        active: GlobalStates.overviewOpen && !root.backdropCaptureTimedOut

        sourceComponent: Item {
            id: pipeline

            readonly property real padding: 48
            readonly property real screenWidth: Math.max(1, root.screen?.width ?? root.width)
            readonly property real screenHeight: Math.max(1, root.screen?.height ?? root.height)
            readonly property real panelX: (screenWidth - root.width) / 2
            readonly property real panelY: liquidGlassSurface.screenY
                - (!Config.options.bar.vertical && !Config.options.bar.bottom ? Appearance.sizes.barHeight : 0)
            readonly property real cropX: Math.max(0, panelX - padding)
            readonly property real cropY: Math.max(0, panelY - padding)
            readonly property real cropRight: Math.min(screenWidth,
                panelX + Math.max(liquidGlassSurface.width, root.retainedBackdropWidth) + padding)
            readonly property real cropBottom: Math.min(screenHeight,
                panelY + Math.max(liquidGlassSurface.height, root.retainedBackdropHeight) + padding)
            readonly property real targetOffsetX: panelX - cropX
            readonly property real targetOffsetY: panelY - cropY
            readonly property real sourceWidth: backdrop.width
            readonly property real sourceHeight: backdrop.height
            readonly property var source: backdrop
            readonly property bool ready: capture.hasContent

            width: 1
            height: 1

            ScreencopyView {
                id: capture
                width: pipeline.screenWidth
                height: pipeline.screenHeight
                captureSource: root.screen
                live: false
                paintCursor: false
            }

            ShaderEffectSource {
                id: crop
                visible: false
                width: Math.max(1, pipeline.cropRight - pipeline.cropX)
                height: Math.max(1, pipeline.cropBottom - pipeline.cropY)
                sourceItem: capture
                sourceRect: Qt.rect(pipeline.cropX, pipeline.cropY, width, height)
                textureSize: Qt.size(
                    Math.ceil(width * (root.screen?.devicePixelRatio ?? 1)),
                    Math.ceil(height * (root.screen?.devicePixelRatio ?? 1))
                )
                hideSource: true
                live: capture.hasContent
            }

            MultiEffect {
                id: blur
                width: crop.width
                height: crop.height
                source: crop
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 40
                blur: 1
            }

            ShaderEffectSource {
                id: backdrop
                visible: false
                width: blur.width
                height: blur.height
                sourceItem: blur
                sourceRect: Qt.rect(0, 0, width, height)
                textureSize: Qt.size(
                    Math.ceil(width * (root.screen?.devicePixelRatio ?? 1)),
                    Math.ceil(height * (root.screen?.devicePixelRatio ?? 1))
                )
                hideSource: true
                live: capture.hasContent
            }
        }
    }

    Connections {
        target: GlobalStates

        function onOverviewOpenChanged() {
            root.backdropCaptureTimedOut = false;
            if (GlobalStates.overviewOpen) {
                root.scheduleResultsRefresh();
                root.retainBackdropSize(gridLayout.implicitWidth, gridLayout.implicitHeight);
            }
        }
    }

    Timer {
        interval: 200
        running: GlobalStates.overviewOpen && !(liquidGlassPipeline.item?.ready ?? false)
        onTriggered: root.backdropCaptureTimedOut = true
    }

    Item { // Background
        id: searchWidgetContent
        clip: true
        implicitWidth: gridLayout.implicitWidth
        implicitHeight: gridLayout.implicitHeight
        property real radius: Config.options.appearance.sharpMode ? 0 : searchBar.height / 2 + searchBar.verticalPadding
        property real opticalEnergy: glassHover.hovered ? 0.48 : 0
        property real opticalX: glassHover.hovered
            ? Math.max(0, Math.min(1, glassHover.point.position.x / Math.max(1, width))) : 0.5
        property real opticalY: glassHover.hovered
            ? Math.max(0, Math.min(1, glassHover.point.position.y / Math.max(1, height))) : 0.5

        Behavior on opticalEnergy {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opticalX {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opticalY {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: glassHover
            enabled: GlobalStates.overviewOpen
            blocking: false
        }

        LiquidGlassSurface {
            id: liquidGlassSurface
            anchors.fill: parent
            shown: GlobalStates.overviewOpen
            wallpaperSource: liquidGlassPipeline.item?.source ?? null
            sourceReady: liquidGlassPipeline.item?.ready ?? false
            sourceFillsItem: true
            enhancedOptics: true
            interactiveOptics: true
            interaction: searchWidgetContent.opticalEnergy
            interactionPoint: Qt.point(searchWidgetContent.opticalX, searchWidgetContent.opticalY)
            thicknessOverride: 0.15
            edgeLighting: 0
            refraction: 0
            itemSourceRect: {
                const pipeline = liquidGlassPipeline.item;
                if (!pipeline)
                    return Qt.rect(0, 0, 1, 1);
                return Qt.rect(
                    pipeline.targetOffsetX / pipeline.sourceWidth,
                    pipeline.targetOffsetY / pipeline.sourceHeight,
                    width / pipeline.sourceWidth,
                    height / pipeline.sourceHeight
                );
            }
            screen: root.screen
            tintColor: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.62)
            radius: searchWidgetContent.radius
        }

        GridLayout {
            id: gridLayout
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 1

            onImplicitWidthChanged: root.retainBackdropSize(implicitWidth, implicitHeight)
            onImplicitHeightChanged: root.retainBackdropSize(implicitWidth, implicitHeight)

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
                forceExpanded: root.showResults
                resultCount: root.activeResultCount
                currentIndex: root.activeCurrentIndex
                navigationColumns: root.appMode ? root.appGridColumns : 1
                resultAt: root.resultAt
                executeResult: entry => LauncherSearch.executeResult(entry)
                moveSelection: (delta, linear) => root.moveSelection(delta, linear)
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

            Item {
                id: resultsViewport
                visible: root.showResults
                Layout.preferredWidth: root.resultsViewportWidth
                Layout.minimumWidth: root.resultsViewportWidth
                Layout.maximumWidth: root.resultsViewportWidth
                Layout.preferredHeight: root.resultsViewportHeight
                Layout.minimumHeight: root.resultsViewportHeight
                Layout.maximumHeight: root.resultsViewportHeight
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                clip: true

                ScriptModel {
                    id: resultModel
                    objectProp: "key"
                }

                GridView {
                    id: appGrid
                    visible: root.appMode
                    anchors.fill: parent
                    clip: true
                    cellWidth: root.appGridCellWidth
                    cellHeight: root.appGridCellHeight
                    model: root.nativeAppSearchActive ? NativeAppSearch.model : resultModel
                    delegate: AppGridItem {}
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true
                    keyNavigationWraps: false
                    highlightMoveDuration: 100
                    ScrollBar.vertical: StyledScrollBar {}

                    onCountChanged: {
                        if (count <= 0)
                            currentIndex = -1;
                        else if (currentIndex < 0 || currentIndex >= count)
                            currentIndex = 0;
                    }
                }

                ListView {
                    id: listResults
                    visible: !root.appMode
                    anchors.fill: parent
                    clip: true
                    topMargin: 10
                    bottomMargin: 10
                    spacing: 2
                    model: resultModel
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true
                    KeyNavigation.up: searchBar
                    highlightMoveDuration: 100
                    ScrollBar.vertical: StyledScrollBar {}

                    onCountChanged: {
                        if (count <= 0)
                            currentIndex = -1;
                        else if (currentIndex < 0 || currentIndex >= count)
                            currentIndex = 0;
                    }
                    onFocusChanged: {
                        if (focus)
                            root.focusFirstItem();
                    }

                    delegate: SearchItem {
                        id: searchItem

                        required property int index
                        required property var modelData
                        anchors.left: parent?.left
                        anchors.right: parent?.right
                        entry: modelData
                        query: {
                            const prefix = LauncherSearch.matchedPrefix(root.searchingText)
                            return prefix ? StringUtils.cleanPrefix(root.searchingText, prefix) : root.searchingText
                        }
                        current: listResults.currentIndex === index
                        containerRadius: searchWidgetContent.radius

                        onHoveredChanged: {
                            if (hovered && listResults.currentIndex !== index)
                                listResults.currentIndex = index;
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                if (listResults.count === 0)
                                    return;
                                const tabbedText = root.resultAt(0)?.name ?? "";
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
}
