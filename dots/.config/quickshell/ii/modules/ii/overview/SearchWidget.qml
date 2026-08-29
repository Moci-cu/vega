pragma ComponentBehavior: Bound

import Qt.labs.synchronizer
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
    readonly property int appGridColumns: 7
    readonly property int appGridRows: 4
    readonly property int appGridCapacity: appGridColumns * appGridRows
    readonly property real appGridCellWidth: 88
    readonly property real appGridCellHeight: 90
    readonly property real resultsViewportWidth: appGridColumns * appGridCellWidth
    readonly property real resultsViewportHeight: appGridRows * appGridCellHeight
    readonly property real resultsPanelWidth: resultsViewportWidth + 24
    readonly property real resultsPanelHeight: resultsViewportHeight + 24
    readonly property real searchPillWidth: 500
    readonly property real searchPillHeight: 64
    readonly property real searchPanelGap: 8
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
    implicitHeight: searchWidgetContent.implicitHeight + Appearance.sizes.elevationMargin * 2
    width: implicitWidth
    height: implicitHeight

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

    function backdropRectFor(item) {
        const pipeline = liquidGlassPipeline.item;
        if (!pipeline || !item)
            return Qt.rect(0, 0, 1, 1);
        const localPosition = item.mapToItem(searchWidgetContent, 0, 0);
        return Qt.rect(
            (pipeline.targetOffsetX + localPosition.x) / pipeline.sourceWidth,
            (pipeline.targetOffsetY + localPosition.y) / pipeline.sourceHeight,
            item.width / pipeline.sourceWidth,
            item.height / pipeline.sourceHeight
        );
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
        readonly property var entry: {
            const modelEntry = gridItem.modelData;
            return root.resultAt(gridItem.index) ?? modelEntry;
        }

        width: root.appGridCellWidth
        height: root.appGridCellHeight
        toggled: appGrid.currentIndex === index
        rippleEnabled: false
        buttonRadius: root.sharpMode ? 0 : 15
        buttonRadiusPressed: root.sharpMode ? 0 : 12
        colBackground: "transparent"
        colBackgroundHover: "transparent"
        colBackgroundToggled: "transparent"
        colBackgroundToggledHover: "transparent"

        background {
            visible: false
        }

        onHoveredChanged: {
            if (hovered && appGrid.currentIndex !== index)
                appGrid.currentIndex = index;
        }
        onClicked: {
            GlobalStates.overviewOpen = false;
            LauncherSearch.executeResult(gridItem.entry);
        }

        contentItem: Item {
            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(1, parent.width - 8)
                spacing: 4

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 60

                    Rectangle {
                        anchors.centerIn: parent
                        width: 64
                        height: 60
                        radius: root.sharpMode ? 0 : 16
                        color: gridItem.toggled ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                        border.width: gridItem.toggled ? 0.6 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.16)

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 48
                        height: 48
                        source: AppSearch.iconPath(gridItem.entry?.iconName ?? "", "image-missing")
                        asynchronous: true
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    color: Qt.rgba(1, 1, 1, gridItem.toggled ? 0.98 : 0.88)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    text: gridItem.entry?.name ?? ""
                }
            }
        }
    }

    component GlassOutline: Item {
        id: outline

        required property real cornerRadius
        required property color tintColor
        property real interaction: 0
        property real highlightOpacity: 0.24

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: outline.cornerRadius
            border.width: 0.65
            border.color: ColorUtils.applyAlpha(
                ColorUtils.mix("black", outline.tintColor, 0.3),
                Math.max(0.42, outline.tintColor.a)
            )
            antialiasing: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 0.8
                color: "transparent"
                radius: Math.max(0, parent.radius - 0.8)
                border.width: 0.8
                border.color: ColorUtils.applyAlpha(
                    ColorUtils.mix("white", outline.tintColor, 0.52),
                    outline.highlightOpacity + 0.06 * outline.interaction
                )
                antialiasing: true
            }
        }
    }

    Loader {
        id: liquidGlassPipeline
        active: GlobalStates.overviewOpen

        sourceComponent: Item {
            id: pipeline

            readonly property real padding: 48
            readonly property real screenWidth: Math.max(1, root.screen?.width ?? root.width)
            readonly property real screenHeight: Math.max(1, root.screen?.height ?? root.height)
            readonly property real panelX: (screenWidth - searchWidgetContent.width) / 2
            readonly property real panelY: searchGlassSurface.screenY
                - (!Config.options.bar.vertical && !Config.options.bar.bottom ? Appearance.sizes.barHeight : 0)
            readonly property real cropX: Math.max(0, panelX - padding)
            readonly property real cropY: Math.max(0, panelY - padding)
            readonly property real cropRight: Math.min(screenWidth,
                panelX + Math.max(searchWidgetContent.width, root.retainedBackdropWidth) + padding)
            readonly property real cropBottom: Math.min(screenHeight,
                panelY + Math.max(searchWidgetContent.height, root.retainedBackdropHeight) + padding)
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
                root.retainBackdropSize(searchWidgetContent.implicitWidth, searchWidgetContent.implicitHeight);
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

        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        implicitWidth: root.resultsPanelWidth
        implicitHeight: root.searchPillHeight + root.searchPanelGap + root.resultsPanelHeight
        readonly property real searchRadius: root.sharpMode ? 0 : root.searchPillHeight / 2
        readonly property real panelRadius: root.sharpMode ? 0 : 28
        property real opticalEnergy: glassHover.hovered ? 0.48 : 0

        function interactionPointFor(item) {
            if (!glassHover.hovered)
                return Qt.point(0.5, 0.5);
            const localPosition = item.mapFromItem(
                searchWidgetContent,
                glassHover.point.position.x,
                glassHover.point.position.y
            );
            return Qt.point(
                Math.max(0, Math.min(1, localPosition.x / Math.max(1, item.width))),
                Math.max(0, Math.min(1, localPosition.y / Math.max(1, item.height)))
            );
        }

        Behavior on opticalEnergy {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: glassHover
            enabled: GlobalStates.overviewOpen
            blocking: false
        }

        Item {
            id: searchPill

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.searchPillWidth
            height: root.searchPillHeight
            z: 2

            RectangularShadow {
                anchors.fill: parent
                radius: searchWidgetContent.searchRadius
                blur: 8
                offset: Qt.vector2d(0, 1)
                spread: -1
                color: Qt.rgba(0, 0, 0, 0.34)
                cached: true
            }

            LiquidGlassSurface {
                id: searchGlassSurface

                anchors.fill: parent
                shown: GlobalStates.overviewOpen
                wallpaperSource: liquidGlassPipeline.item?.source ?? null
                sourceReady: liquidGlassPipeline.item?.ready ?? false
                sourceFillsItem: true
                enhancedOptics: true
                interactiveOptics: true
                interaction: Math.min(1, searchWidgetContent.opticalEnergy * 1.5)
                interactionPoint: searchWidgetContent.interactionPointFor(searchPill)
                thicknessOverride: 0.34
                edgeLighting: 0.58
                lowerGlow: 1
                refraction: 0
                itemSourceRect: root.backdropRectFor(searchGlassSurface)
                screen: root.screen
                tintColor: Qt.rgba(0, 0, 0, 0.68)
                radius: searchWidgetContent.searchRadius
            }

            SearchBar {
                id: searchBar

                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                anchors.topMargin: 9
                anchors.bottomMargin: 9
                debounceInterval: root.typingDebounceInterval
                forceExpanded: true
                resultCount: root.activeResultCount
                currentIndex: root.activeCurrentIndex
                navigationColumns: root.appMode ? root.appGridColumns : 1
                selectedResult: root.appMode
                    ? (appGrid.currentItem?.entry ?? null)
                    : (listResults.currentItem?.entry ?? null)
                resultAt: root.resultAt
                executeResult: entry => LauncherSearch.executeResult(entry)
                moveSelection: (delta, linear) => root.moveSelection(delta, linear)
                autocompleteWallpaperSource: liquidGlassPipeline.item?.source ?? null
                autocompleteSourceReady: liquidGlassPipeline.item?.ready ?? false
                autocompleteSourceRectFor: item => root.backdropRectFor(item)
                autocompleteScreen: root.screen

                Synchronizer on searchingText {
                    property alias source: root.searchingText
                }
            }

        }

        Item {
            id: resultsPanel

            anchors.top: searchPill.bottom
            anchors.topMargin: root.searchPanelGap
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.resultsPanelWidth
            height: root.resultsPanelHeight
            z: 1

            RectangularShadow {
                anchors.fill: parent
                radius: searchWidgetContent.panelRadius
                blur: 16
                offset: Qt.vector2d(0, 3)
                spread: -2
                color: Qt.rgba(0, 0, 0, 0.32)
                cached: true
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
                interactionPoint: searchWidgetContent.interactionPointFor(resultsPanel)
                thicknessOverride: 0.18
                edgeLighting: 0.16
                refraction: 0
                itemSourceRect: root.backdropRectFor(liquidGlassSurface)
                screen: root.screen
                tintColor: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.62)
                radius: searchWidgetContent.panelRadius
            }

            Item {
                id: resultsViewport

                visible: root.showResults
                anchors.fill: parent
                anchors.margins: 12
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
                    topMargin: 8
                    bottomMargin: 8
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
                        containerRadius: searchWidgetContent.panelRadius

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

            GlassOutline {
                anchors.fill: parent
                cornerRadius: searchWidgetContent.panelRadius
                tintColor: liquidGlassSurface.tintColor
                interaction: searchWidgetContent.opticalEnergy
                highlightOpacity: 0.2
            }
        }
    }
}
