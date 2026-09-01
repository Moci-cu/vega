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

    signal resultsPanelHidden()

    readonly property string xdgConfigHome: Directories.config
    readonly property int typingDebounceInterval: 35
    readonly property int typingResultLimit: 7
    readonly property int clipboardVisibleRowLimit: 8
    readonly property real clipboardRowHeight: 58
    readonly property real clipboardRowSpacing: 2
    readonly property int appGridColumns: 7
    readonly property int appGridRows: 4
    readonly property int appGridCapacity: appGridColumns * appGridRows
    readonly property real appGridCellWidth: 110
    readonly property real appGridCellHeight: 104
    readonly property real resultsViewportWidth: appGridColumns * appGridCellWidth
    readonly property real resultsViewportHeight: appGridRows * appGridCellHeight
    readonly property real resultsPanelWidth: resultsViewportWidth + 24
    readonly property real resultsPanelHeight: resultsViewportHeight + 24
    readonly property real clipboardPanelHeight: clipboardVisibleRowLimit * clipboardRowHeight
        + (clipboardVisibleRowLimit - 1) * clipboardRowSpacing + 40
    readonly property real activeResultsPanelHeight: clipboardMode ? clipboardPanelHeight : resultsPanelHeight
    readonly property real categoryPanelWidth: searchPillWidth
    readonly property real categoryRowHeight: 40
    readonly property real categoryPanelHeight: categoryRowHeight * categoryEntries.length + 24
    readonly property var categoryEntries: [
        { label: "Applications", icon: "apps", themedIcon: "penguin-symbolic" },
        { label: "Files", icon: "folder" },
        { label: "Actions", icon: "layers" },
        { label: "Clipboard", icon: "content_copy" }
    ]
    readonly property real searchPillWidth: 490
    readonly property real searchPillHeight: 90
    readonly property real calculatorPanelHeight: 64
    readonly property real wifiCommandRowHeight: 52
    readonly property real wifiCommandInlineHeight: LauncherSearch.wifiCommandActions.length
        * wifiCommandRowHeight + 16
    readonly property real searchPanelGap: 8
    readonly property var screen: root.QsWindow.window?.screen ?? null

    readonly property bool sharpMode: Config.options.appearance.sharpMode
    readonly property bool useCompositorBackdrop: true
    readonly property bool backdropReady: backdropSettled || backdropCaptureTimedOut
    readonly property bool appMode: LauncherSearch.isApplicationQuery(root.searchingText)
    readonly property bool nativeAppSearchActive: LauncherSearch.shouldUseNativeAppSearch(root.searchingText)
    readonly property bool wifiCommandMode: LauncherSearch.isWifiCommandQuery(root.searchingText)
    readonly property bool resultsVisible: showResults || wifiPanelOpen
    readonly property bool appResultsReady: !appMode || (nativeAppSearchActive
        ? nativeResultQuery === searchingText && !(NativeAppSearch.model?.busy ?? false)
        : fallbackAppQuery === searchingText)
    readonly property int activeResultCount: wifiPanelOpen
        ? (wifiPanelLoader.item?.networkCount ?? 0) : wifiCommandMode
            ? wifiCommandList.count : appMode
                ? (!showResults && nativeAutocompleteResult
                    ? Math.max(1, appGrid.count) : appGrid.count)
                : listResults.count
    readonly property int activeCurrentIndex: wifiPanelOpen
        ? (wifiPanelLoader.item?.currentIndex ?? -1) : wifiCommandMode
            ? wifiCommandList.currentIndex : appMode
                ? (!showResults && nativeAutocompleteResult
                    ? Math.max(0, appGrid.currentIndex) : appGrid.currentIndex)
                : listResults.currentIndex
    property string searchingText: LauncherSearch.query
    property var clipboardEntries: []
    property var fallbackAppEntries: []
    property string fallbackAppQuery: ""
    property bool showResults: false
    property bool applicationGridMode: false
    property bool showCategories: false
    property bool showClipboard: false
    property bool wifiPanelOpen: false
    readonly property bool clipboardMode: showClipboard
    readonly property string calculatorExpression: applicationGridMode || clipboardMode || wifiPanelOpen
        ? "" : LauncherSearch.mathExpression(searchingText)
    readonly property string calculatorResult: LauncherSearch.mathResult.trim()
    readonly property bool calculatorActive: calculatorExpression.length > 0
    readonly property bool calculatorVisible: calculatorActive
    property real searchSurfaceHeight: searchPillHeight
        + (calculatorActive ? calculatorPanelHeight
            : wifiCommandMode ? wifiCommandInlineHeight : 0)
    readonly property bool deepGlassMode: appMode || clipboardMode || wifiPanelOpen
    readonly property bool categoriesVisible: showCategories
        && !showResults
        && searchingText.trim().length === 0
    property real revealProgress: 1
    property real visualScale: 1
    property bool backdropSettled: false
    property bool backdropCaptureTimedOut: false
    property string pendingResultQuery: ""
    property var pendingResultAction: null
    property string nativeResultQuery: ""
    property var nativeAutocompleteResult: null
    property real retainedBackdropWidth: resultsPanelWidth + 4
    property real retainedBackdropHeight: searchPillHeight + searchPanelGap
        + Math.max(resultsPanelHeight, clipboardPanelHeight) + 4
    implicitWidth: searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchWidgetContent.implicitHeight + Appearance.sizes.elevationMargin * 2
    width: implicitWidth
    height: implicitHeight

    Behavior on searchSurfaceHeight {
        enabled: GlobalStates.overviewOpen

        NumberAnimation {
            duration: 280
            easing.type: Easing.OutBack
            easing.overshoot: 0.12
        }
    }

    function retainBackdropSize(targetWidth, targetHeight) {
        if (!GlobalStates.overviewOpen)
            return;
        root.retainedBackdropWidth = Math.max(root.retainedBackdropWidth, targetWidth + 4);
        root.retainedBackdropHeight = Math.max(root.retainedBackdropHeight, targetHeight + 4);
    }

    function focusFirstItem() {
        if (root.wifiPanelOpen) {
            wifiPanelLoader.item?.moveSelection(0);
            return;
        }
        if (root.wifiCommandMode) {
            if (wifiCommandList.count > 0)
                wifiCommandList.currentIndex = 0;
            return;
        }
        const view = root.appMode ? appGrid : listResults;
        if (view.count <= 0)
            return;
        if (view.currentIndex !== 0)
            view.currentIndex = 0;
        view.positionViewAtIndex(0, root.appMode ? GridView.Contain : ListView.Contain);
    }

    function moveSelection(delta, linear = false) {
        if (root.wifiPanelOpen) {
            wifiPanelLoader.item?.moveSelection(delta);
            return;
        }
        if (root.wifiCommandMode) {
            if (wifiCommandList.count <= 0) return;
            wifiCommandList.currentIndex = Math.max(0,
                Math.min(wifiCommandList.count - 1,
                    Math.max(0, wifiCommandList.currentIndex) + delta));
            return;
        }
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
        if (root.wifiPanelOpen)
            return null;
        if (root.nativeAppSearchActive)
            return NativeAppSearch.get(index);
        const values = root.clipboardMode ? root.clipboardEntries : resultModel.values;
        const value = values[index];
        if (!root.clipboardMode || value === undefined)
            return value;
        return LauncherSearch.clipboardResult(value, index, values);
    }

    function cancelPendingResultAction() {
        root.pendingResultQuery = "";
        root.pendingResultAction = null;
    }

    function runAfterResultsRefresh(query, action) {
        root.pendingResultQuery = query;
        root.pendingResultAction = action;
        LauncherSearch.query = query;
        root.scheduleResultsRefresh();
    }

    function finishResultsRefresh(query) {
        Qt.callLater(() => {
            if (query !== root.searchingText)
                return;
            root.focusFirstItem();
            if (query !== root.pendingResultQuery || !root.pendingResultAction)
                return;
            const action = root.pendingResultAction;
            root.cancelPendingResultAction();
            action();
        });
    }

    function backdropRectFor(item, visualScale) {
        const pipeline = liquidGlassPipeline.item;
        if (!pipeline || !item)
            return Qt.rect(0, 0, 1, 1);
        item.x;
        item.y;
        item.scale;
        let ancestor = item.parent;
        while (ancestor && ancestor !== searchWidgetContent) {
            ancestor.x;
            ancestor.y;
            ancestor.width;
            ancestor.height;
            ancestor.scale;
            ancestor = ancestor.parent;
        }
        const topLeft = item.mapToItem(searchWidgetContent, 0, 0);
        const bottomRight = item.mapToItem(searchWidgetContent, item.width, item.height);
        const left = Math.min(topLeft.x, bottomRight.x);
        const top = Math.min(topLeft.y, bottomRight.y);
        const width = Math.abs(bottomRight.x - topLeft.x);
        const height = Math.abs(bottomRight.y - topLeft.y);
        const originX = searchWidgetContent.width / 2;
        const originY = root.searchPillHeight / 2;
        const leftScaled = originX + (left - originX) * visualScale;
        const topScaled = originY + (top - originY) * visualScale;
        return Qt.rect(
            (pipeline.targetOffsetX + leftScaled) / pipeline.sourceWidth,
            (pipeline.targetOffsetY + topScaled) / pipeline.sourceHeight,
            width * visualScale / pipeline.sourceWidth,
            height * visualScale / pipeline.sourceHeight
        );
    }

    function refreshResults() {
        const refreshedQuery = root.searchingText;
        if (root.wifiPanelOpen) {
            NativeAppSearch.clear();
            root.fallbackAppEntries = [];
            root.fallbackAppQuery = "";
            resultModel.values = [];
            root.finishResultsRefresh(refreshedQuery);
            return;
        }
        if (root.clipboardMode) {
            NativeAppSearch.clear();
            root.fallbackAppEntries = [];
            root.fallbackAppQuery = "";
            const searchString = StringUtils.cleanPrefix(
                root.searchingText,
                Config.options.search.prefix.clipboard
            );
            root.clipboardEntries = Cliphist.fuzzyQuery(searchString);
            resultModel.values = [];
            root.finishResultsRefresh(refreshedQuery);
            return;
        }

        root.clipboardEntries = [];
        if (root.appMode) {
            const query = LauncherSearch.nativeAppQuery(root.searchingText);
            const blankQuery = query.trim().length === 0;
            const limit = root.showResults
                ? (blankQuery ? Math.max(root.appGridCapacity, AppSearch.list.length) : root.appGridCapacity)
                : (blankQuery ? 0 : 1);
            if (root.nativeAppSearchActive) {
                root.fallbackAppEntries = [];
                root.fallbackAppQuery = "";
                root.nativeResultQuery = refreshedQuery;
                root.nativeAutocompleteResult = null;
                NativeAppSearch.search(query, limit);
                return;
            }
            NativeAppSearch.clear();
            const values = LauncherSearch.results;
            const appValues = blankQuery
                ? (limit === 0 ? [] : Array.from(AppSearch.list)
                    .sort((left, right) => String(left.name).localeCompare(String(right.name)))
                    .map(entry => LauncherSearch.appResult(entry)))
                : (values ?? []).filter(entry => String(entry?.key ?? "").startsWith("app:")).slice(0, limit);
            const firstStartsWithQuery = appValues.length > 0
                && String(appValues[0].name ?? "").toLowerCase().startsWith(query.trim().toLowerCase());
            const keywordFallback = !root.showResults && !firstStartsWithQuery
                ? LauncherSearch.wifiKeywordResult(query) : null;
            root.fallbackAppEntries = keywordFallback ? [keywordFallback] : appValues;
            root.fallbackAppQuery = refreshedQuery;
            resultModel.values = [];
            root.finishResultsRefresh(refreshedQuery);
            return;
        }
        NativeAppSearch.clear();
        root.fallbackAppEntries = [];
        root.fallbackAppQuery = "";
        const values = LauncherSearch.results;
        resultModel.values = (values ?? []).slice(0, root.typingResultLimit);
        root.finishResultsRefresh(refreshedQuery);
    }

    function scheduleResultsRefresh() {
        resultsRefreshTimer.restart();
    }

    onSearchingTextChanged: {
        if (root.pendingResultAction && root.searchingText !== root.pendingResultQuery)
            root.cancelPendingResultAction();
        root.scheduleResultsRefresh();
    }
    onAppModeChanged: root.scheduleResultsRefresh()
    onNativeAppSearchActiveChanged: root.scheduleResultsRefresh()
    onShowResultsChanged: root.scheduleResultsRefresh()
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
            const firstResult = NativeAppSearch.get(0);
            const query = LauncherSearch.nativeAppQuery(root.nativeResultQuery).trim().toLowerCase();
            const firstStartsWithQuery = firstResult
                && String(firstResult.name ?? "").toLowerCase().startsWith(query);
            root.nativeAutocompleteResult = firstStartsWithQuery ? firstResult
                : (LauncherSearch.wifiKeywordResult(query) ?? firstResult);
            root.finishResultsRefresh(root.nativeResultQuery);
        }
    }

    Connections {
        target: LauncherSearch

        function onResultsChanged() {
            root.scheduleResultsRefresh();
        }

        function onWifiPanelRequested() {
            root.wifiPanelOpen = true;
            root.setSearchingText("");
            Qt.callLater(root.focusSearchInput);
        }
    }

    Connections {
        target: GlobalStates

        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen)
                root.wifiPanelOpen = false;
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
            if (!root.nativeAppSearchActive)
                return modelEntry;
            const nativeEntry = NativeAppSearch.get(gridItem.index);
            return nativeEntry?.key ? nativeEntry : modelEntry;
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
            if (hovered && !appGrid.moving && appGrid.currentIndex !== index)
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
                        width: 52
                        height: 52
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
            readonly property var environmentSource: crop
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
                live: capture.hasContent && (!root.backdropSettled || root.visualScale !== 1)
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
                live: capture.hasContent && (!root.backdropSettled || root.visualScale !== 1)
            }
        }
    }

    Connections {
        target: GlobalStates

        function onOverviewOpenChanged() {
            root.backdropSettled = false;
            root.backdropCaptureTimedOut = false;
            if (GlobalStates.overviewOpen) {
                root.scheduleResultsRefresh();
                root.retainBackdropSize(searchWidgetContent.implicitWidth, searchWidgetContent.implicitHeight);
            }
        }
    }

    Timer {
        interval: 34
        running: GlobalStates.overviewOpen
            && !root.backdropSettled
            && (liquidGlassPipeline.item?.ready ?? false)
        onTriggered: root.backdropSettled = true
    }

    Timer {
        interval: 800
        running: GlobalStates.overviewOpen && !(liquidGlassPipeline.item?.ready ?? false)
        onTriggered: root.backdropCaptureTimedOut = true
    }

    Item { // Background
        id: searchWidgetContent

        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        implicitWidth: root.resultsPanelWidth
        implicitHeight: root.searchSurfaceHeight
            + (root.resultsVisible
                ? root.searchPanelGap + root.activeResultsPanelHeight
                : root.categoriesVisible ? root.searchPanelGap + root.categoryPanelHeight : 0)
        readonly property real searchRadius: root.sharpMode ? 0 : root.searchPillHeight / 2
        readonly property real categoryRadius: root.sharpMode ? 0 : 36
        readonly property real panelRadius: root.sharpMode ? 0 : (root.clipboardMode ? 36 : 28)
        property real opticalEnergy: glassHover.hovered ? 0.48 : 0

        onImplicitWidthChanged: root.retainBackdropSize(implicitWidth, implicitHeight)
        onImplicitHeightChanged: root.retainBackdropSize(implicitWidth, implicitHeight)

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
            height: root.searchSurfaceHeight
            z: 2

            LiquidGlassSurface {
                id: searchGlassSurface

                anchors.fill: parent
                shown: GlobalStates.overviewOpen
                compositorBackdrop: root.useCompositorBackdrop
                wallpaperSource: liquidGlassPipeline.item?.source ?? null
                environmentSource: liquidGlassPipeline.item?.environmentSource ?? null
                sourceReady: liquidGlassPipeline.item?.ready ?? false
                sourceFillsItem: true
                interactiveOptics: true
                interaction: Math.min(1, searchWidgetContent.opticalEnergy * 1.5)
                interactionPoint: searchWidgetContent.interactionPointFor(searchPill)
                thicknessOverride: 0.34
                edgeLighting: 0.82
                lowerGlow: 1
                enhancedOptics: true
                ambientDiffusion: 1
                detailedEnvironment: true
                refraction: 0
                itemSourceRect: root.backdropRectFor(searchGlassSurface, root.visualScale)
                screen: root.screen
                tintColor: Qt.rgba(0, 0, 0, root.useCompositorBackdrop ? 0.595 : 0.74)
                radius: searchWidgetContent.searchRadius
            }

            SearchBar {
                id: searchBar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 26
                anchors.rightMargin: 10
                anchors.topMargin: 9
                height: root.searchPillHeight - 18
                debounceInterval: root.typingDebounceInterval
                forceExpanded: true
                calculatorActive: root.calculatorActive
                queryPrefix: root.applicationGridMode ? Config.options.search.prefix.app
                    : root.clipboardMode ? Config.options.search.prefix.clipboard : ""
                inputPlaceholder: root.wifiPanelOpen ? Translation.tr("Search Wi-Fi networks…")
                    : root.clipboardMode && root.showResults
                        ? Translation.tr("Clipboard") : Translation.tr("Search or Ask")
                leadingIcon: root.wifiPanelOpen ? "wifi"
                    : root.clipboardMode && root.showResults ? "content_copy" : ""
                resultCount: root.activeResultCount
                currentIndex: root.activeCurrentIndex
                navigationColumns: root.wifiPanelOpen ? 1 : root.appMode ? root.appGridColumns : 1
                selectedResult: root.wifiPanelOpen ? null
                    : root.wifiCommandMode ? (wifiCommandList.currentItem?.entry ?? null)
                    : root.appMode ? (!root.showResults && root.nativeAppSearchActive
                        ? root.nativeAutocompleteResult : (appGrid.currentItem?.entry ?? null))
                    : (listResults.currentItem?.entry ?? null)
                resultAt: root.resultAt
                executeResult: entry => LauncherSearch.executeResult(entry)
                moveSelection: (delta, linear) => root.moveSelection(delta, linear)
                runAfterQueryCommitted: (query, action) => root.runAfterResultsRefresh(query, action)
                cancelPendingQueryAction: () => root.cancelPendingResultAction()
                autocompleteScreen: root.screen

                Synchronizer on searchingText {
                    property alias source: root.searchingText
                }
            }

            Item {
                id: calculatorPanel

                visible: opacity > 0
                opacity: root.calculatorVisible
                    ? Math.max(0, Math.min(1, (root.searchSurfaceHeight
                        - root.searchPillHeight - 12) / (root.calculatorPanelHeight - 12)))
                    : 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: root.searchPillHeight - 2
                height: root.calculatorPanelHeight - 10

                Rectangle {
                    anchors.fill: parent
                    radius: root.sharpMode ? 0 : height / 2
                    color: Qt.rgba(0.82, 0.84, 0.86, 0.16)
                    border.width: 0.6
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: -1

                        StyledText {
                            Layout.fillWidth: true
                            text: `${root.calculatorExpression} =`
                            color: Qt.rgba(1, 1, 1, 0.64)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            renderType: Text.QtRendering
                            elide: Text.ElideLeft
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.calculatorResult || "…"
                            color: Qt.rgba(1, 1, 1, 0.94)
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            renderType: Text.QtRendering
                            elide: Text.ElideLeft
                        }
                    }

                    IconToolbarButton {
                        id: calculatorCopyButton

                        enabled: root.calculatorResult.length > 0
                        opacity: enabled ? 1 : 0.45
                        Layout.fillHeight: false
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        buttonRadius: 14
                        text: "content_copy"
                        colText: Qt.rgba(1, 1, 1, 0.82)
                        colBackground: Qt.rgba(1, 1, 1, 0.12)
                        onClicked: Quickshell.clipboardText = root.calculatorResult

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 17
                            text: calculatorCopyButton.text
                            color: calculatorCopyButton.colText
                        }

                        StyledToolTip {
                            text: Translation.tr("Copy")
                        }
                    }
                }
            }

            Item {
                id: wifiCommandPanel

                visible: opacity > 0
                opacity: root.wifiCommandMode
                    ? Math.max(0, Math.min(1, (root.searchSurfaceHeight
                        - root.searchPillHeight - 12) / (root.wifiCommandInlineHeight - 12)))
                    : 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: root.searchPillHeight - 2
                height: root.wifiCommandInlineHeight - 8
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.14)
                }

                ListView {
                    id: wifiCommandList

                    anchors.fill: parent
                    anchors.topMargin: 8
                    clip: true
                    spacing: 0
                    model: root.wifiCommandMode ? resultModel : null
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: false

                    onCountChanged: {
                        if (count <= 0)
                            currentIndex = -1;
                        else if (currentIndex < 0 || currentIndex >= count)
                            currentIndex = 0;
                    }

                    delegate: SearchItem {
                        id: wifiCommandItem

                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: root.wifiCommandRowHeight
                        entry: root.resultAt(index)
                        query: root.searchingText
                        current: wifiCommandList.currentIndex === index
                        horizontalMargin: 4
                        containerRadius: searchWidgetContent.searchRadius

                        onHoveredChanged: {
                            if (hovered && wifiCommandList.currentIndex !== index)
                                wifiCommandList.currentIndex = index;
                        }
                    }
                }
            }

        }

        Item {
            id: categoryPanel

            visible: opacity > 0
            opacity: root.categoriesVisible ? 1 : 0
            scale: root.categoriesVisible ? 1 : 0.94
            transformOrigin: Item.Top
            anchors.top: searchPill.bottom
            anchors.topMargin: root.searchPanelGap
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.categoryPanelWidth
            height: root.categoryPanelHeight
            z: 1

            Behavior on opacity {
                enabled: root.revealProgress >= 0.999

                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                enabled: root.revealProgress >= 0.999

                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.25
                }
            }

            LiquidGlassSurface {
                id: categoryGlassSurface

                anchors.fill: parent
                shown: GlobalStates.overviewOpen && root.categoriesVisible
                compositorBackdrop: root.useCompositorBackdrop
                wallpaperSource: liquidGlassPipeline.item?.source ?? null
                environmentSource: liquidGlassPipeline.item?.environmentSource ?? null
                sourceReady: liquidGlassPipeline.item?.ready ?? false
                sourceFillsItem: true
                interactiveOptics: true
                interaction: searchWidgetContent.opticalEnergy
                interactionPoint: searchWidgetContent.interactionPointFor(categoryPanel)
                thicknessOverride: 0.18
                edgeLighting: 0.58
                lowerGlow: 1
                enhancedOptics: true
                refraction: 0
                itemSourceRect: root.backdropRectFor(categoryGlassSurface, root.visualScale)
                screen: root.screen
                tintColor: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer,
                    root.useCompositorBackdrop ? 0.56 : 0.62)
                radius: searchWidgetContent.categoryRadius
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12

                Repeater {
                    model: root.categoryEntries

                    delegate: Item {
                        id: categoryItem

                        required property var modelData
                        width: parent.width
                        height: root.categoryRowHeight

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 14

                            Item {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                Layout.alignment: Qt.AlignVCenter

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: !categoryItem.modelData.themedIcon
                                    iconSize: 23
                                    color: Qt.rgba(1, 1, 1, 0.8)
                                    text: categoryItem.modelData.icon
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    visible: !!categoryItem.modelData.themedIcon
                                    implicitSize: 23
                                    source: Quickshell.iconPath(categoryItem.modelData.themedIcon ?? "", "image-missing")
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: Translation.tr(categoryItem.modelData.label)
                                color: Qt.rgba(1, 1, 1, 0.9)
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: resultsPanel

            visible: opacity > 0
            opacity: root.resultsVisible ? 1 : 0
            scale: root.resultsVisible ? 1 : 0.94
            transformOrigin: Item.Top
            anchors.top: searchPill.bottom
            anchors.topMargin: root.searchPanelGap
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.clipboardMode ? root.searchPillWidth : root.resultsPanelWidth
            height: root.activeResultsPanelHeight
            z: 1

            onVisibleChanged: {
                if (!visible)
                    root.resultsPanelHidden();
            }

            Behavior on opacity {
                enabled: root.revealProgress >= 0.999

                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                enabled: root.revealProgress >= 0.999

                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.25
                }
            }

            LiquidGlassSurface {
                id: liquidGlassSurface

                anchors.fill: parent
                shown: GlobalStates.overviewOpen
                compositorBackdrop: root.useCompositorBackdrop
                wallpaperSource: liquidGlassPipeline.item?.source ?? null
                environmentSource: liquidGlassPipeline.item?.environmentSource ?? null
                sourceReady: liquidGlassPipeline.item?.ready ?? false
                sourceFillsItem: true
                interactiveOptics: !root.deepGlassMode
                interaction: searchWidgetContent.opticalEnergy
                interactionPoint: searchWidgetContent.interactionPointFor(resultsPanel)
                thicknessOverride: root.deepGlassMode ? 0.32 : 0.18
                edgeLighting: root.deepGlassMode ? 0.48 : 0.58
                lowerGlow: root.deepGlassMode ? 0.12 : 1
                enhancedOptics: true
                ambientSpillStrength: root.deepGlassMode ? 0.82 : -1
                refraction: root.deepGlassMode ? 4 : 0
                itemSourceRect: root.backdropRectFor(liquidGlassSurface, root.visualScale)
                screen: root.screen
                tintColor: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer,
                    root.deepGlassMode
                        ? (root.useCompositorBackdrop ? 0.38 : 0.44)
                        : (root.useCompositorBackdrop ? 0.56 : 0.62))
                radius: searchWidgetContent.panelRadius
            }

            Item {
                id: resultsViewport

                anchors.fill: parent
                anchors.margins: 12
                clip: true

                ScriptModel {
                    id: resultModel
                    objectProp: "key"
                }

                GridView {
                    id: appGrid

                    visible: !root.wifiPanelOpen && root.appMode && root.appResultsReady
                    anchors.fill: parent
                    clip: true
                    cellWidth: root.appGridCellWidth
                    cellHeight: root.appGridCellHeight
                    model: root.nativeAppSearchActive ? NativeAppSearch.model : root.fallbackAppEntries
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

                Component {
                    id: searchResultDelegate

                    SearchItem {
                        id: searchItem

                        required property int index
                        required property var modelData
                        anchors.left: parent?.left
                        anchors.right: parent?.right
                        entry: root.resultAt(index)
                        query: {
                            const prefix = LauncherSearch.matchedPrefix(root.searchingText)
                            return prefix ? StringUtils.cleanPrefix(root.searchingText, prefix) : root.searchingText
                        }
                        current: listResults.currentIndex === index
                        containerRadius: searchWidgetContent.panelRadius

                        onHoveredChanged: {
                            if (hovered && !listResults.moving && listResults.currentIndex !== index)
                                listResults.currentIndex = index;
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                if (listResults.count === 0)
                                    return;
                                const tabbedText = root.resultAt(searchItem.index)?.name ?? "";
                                searchBar.setQueryImmediately(tabbedText);
                                event.accepted = true;
                                root.focusSearchInput();
                            }
                        }
                    }
                }

                Component {
                    id: clipboardResultDelegate

                    ClipboardItem {
                        required property int index
                        required property var modelData
                        anchors.left: parent?.left
                        anchors.right: parent?.right
                        entry: root.resultAt(index)
                        current: listResults.currentIndex === index
                        containerRadius: searchWidgetContent.panelRadius

                        onHoveredChanged: {
                            if (hovered && !listResults.moving && listResults.currentIndex !== index)
                                listResults.currentIndex = index;
                        }
                    }
                }

                ListView {
                    id: listResults

                    visible: !root.wifiPanelOpen && !root.appMode
                    anchors.fill: parent
                    clip: true
                    topMargin: 8
                    bottomMargin: 8
                    spacing: 2
                    model: root.clipboardMode ? root.clipboardEntries.length : resultModel
                    cacheBuffer: 0
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

                    delegate: root.clipboardMode ? clipboardResultDelegate : searchResultDelegate
                }

                Loader {
                    id: wifiPanelLoader

                    active: root.wifiPanelOpen
                    visible: active
                    anchors.fill: parent
                    sourceComponent: WifiPanel {
                        filterText: root.searchingText
                    }
                }
            }

        }
    }
}
