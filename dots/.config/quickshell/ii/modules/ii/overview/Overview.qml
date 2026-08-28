import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    property string focusRestoreAddress: ""
    property int focusRestoreGeneration: 0

    signal setSearchingTextRequested(string text)

    function activeToplevelAddress() {
        const address = ToplevelManager.activeToplevel?.HyprlandToplevel?.address
        return address === undefined || address === null ? "" : `0x${address}`
    }

    function rememberFocusedToplevel() {
        focusRestoreGeneration++
        focusRestoreAddress = activeToplevelAddress()
    }

    function restoreFocusedToplevel() {
        const address = focusRestoreAddress
        const generation = focusRestoreGeneration
        focusRestoreAddress = ""
        if (!address)
            return

        // Release the layer-shell keyboard grab before returning input to the client.
        Qt.callLater(function() {
            if (generation !== focusRestoreGeneration || GlobalStates.overviewOpen)
                return
            const activeAddress = overviewScope.activeToplevelAddress()
            if (activeAddress && activeAddress !== address)
                return
            Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`)
        })
    }

    Connections {
        target: GlobalStates

        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen)
                overviewScope.rememberFocusedToplevel()
            else
                overviewScope.restoreFocusedToplevel()
        }
    }

    Variants {
        id: overviewVariant

        property var variantModel: Quickshell.screens

        model: overviewVariant.variantModel

        LazyLoader {
            id: realOverviewLoader
            required property var modelData
            property int monitorIndex: overviewVariant.variantModel.indexOf(modelData)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.name === modelData?.name)
            active: monitorIsFocused

            component: PanelWindow {
                id: root

                readonly property bool monitorIsFocused: realOverviewLoader.monitorIsFocused
                readonly property int monitorIndex: realOverviewLoader.monitorIndex

                readonly property bool isScrollingLayout: Persistent.states.hyprland.layout === "scrolling"
                property string searchingText: ""
                readonly property bool hasSearchQuery: searchingText.length > 0
                readonly property bool showWorkspaceOverview: !hasSearchQuery

                WlrLayershell.namespace: "quickshell:overview"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                color: "transparent"

                mask: Region {
                    item: root.contentShown ? contentItem : null
                }

                property var zoomLevels: {  // has to be reverted compared to background
                    "in": { default: 1, zoomed: 1.04 },
                    "out": { default: 1.04, zoomed: 1 }
                }

                readonly property bool isZoomInStyle: Config.options.overview.scrollingStyle.zoomStyle === "in"
                readonly property bool showOpeningAnimation: Config.options.overview.showOpeningAnimation

                property real defaultRatio: isZoomInStyle ? zoomLevels.in.default : zoomLevels.out.default
                property real zoomedRatio: isZoomInStyle ? zoomLevels.in.zoomed : zoomLevels.out.zoomed

                property bool isResettingZoom: false 
                property real scaleAnimated: showOpeningAnimation ? GlobalStates.overviewOpen ? zoomedRatio : defaultRatio : 1

                readonly property bool launcherReady: GlobalStates.overviewOpen && searchWidget.backdropReady
                property real effectiveScale: showOpeningAnimation ? zoomedRatio - scaleAnimated + 1 : 1 
                property real launcherScale: 1
                property bool workspaceContentReady: false
                readonly property bool contentShown: {
                    if (!showOpeningAnimation) return GlobalStates.overviewOpen;
                    if (isResettingZoom) return false;
                    return isZoomInStyle ? scaleAnimated > defaultRatio : scaleAnimated < defaultRatio;
                }

                onIsZoomInStyleChanged: isResettingZoom = true
                onScaleAnimatedChanged: {
                    if (scaleAnimated === defaultRatio) {
                        isResettingZoom = false
                    }
                }
                onLauncherReadyChanged: {
                    launcherPopAnimation.stop();
                    launcherCloseAnimation.stop();
                    if (launcherReady) {
                        launcherPopAnimation.restart();
                    } else if (!GlobalStates.overviewOpen) {
                        launcherCloseAnimation.restart();
                    }
                }

                // Keep the input-transparent surface alive so opening only has to reveal its content.
                visible: true

                Behavior on scaleAnimated {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
                }

                SequentialAnimation {
                    id: launcherPopAnimation

                    PropertyAction {
                        target: root
                        property: "launcherScale"
                        value: 1.01
                    }
                    PauseAnimation {
                        duration: 30
                    }
                    NumberAnimation {
                        target: root
                        property: "launcherScale"
                        from: 1.01
                        to: 0.99
                        duration: 180
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                    NumberAnimation {
                        target: root
                        property: "launcherScale"
                        from: 0.99
                        to: 1
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.1
                    }
                }

                NumberAnimation {
                    id: launcherCloseAnimation
                    target: root
                    property: "launcherScale"
                    to: 0.9
                    duration: 140
                    easing.type: Easing.InCubic
                }

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                property int barSize: Config.options.bar.vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
                property int margin: isZoomInStyle ? barSize : barSize * 2
                margins { 
                    top: -margin * 2
                    bottom: -margin * 2
                    left: -margin * 2
                    right: -margin * 2
                }

                HyprlandFocusGrab {
                    id: grab
                    windows: [root]
                    property bool canBeActive: root.monitorIsFocused
                    active: false
                    onCleared: () => {
                        if (!active)
                            GlobalStates.overviewOpen = false;
                    }
                }

                Connections {
                    target: GlobalStates
                    function onOverviewOpenChanged() {
                        if (!GlobalStates.overviewOpen) {
                            delayedGrabTimer.stop();
                            grab.active = false;
                            workspaceContentDelayTimer.stop();
                            root.workspaceContentReady = false;
                            searchWidget.disableExpandAnimation();
                            overviewScope.dontAutoCancelSearch = false;
                        } else {
                            launcherCloseAnimation.stop();
                            root.launcherScale = 1;
                            if (!overviewScope.dontAutoCancelSearch) {
                                searchWidget.cancelSearch();
                            }
                            delayedGrabTimer.start();
                        }
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    }
                }

                

                Timer {
                    id: delayedGrabTimer
                    interval: Config.options.hacks.arbitraryRaceConditionDelay
                    repeat: false
                    onTriggered: {
                        if (!grab.canBeActive)
                            return;
                        grab.active = GlobalStates.overviewOpen;
                    }
                }

                Timer {
                    id: workspaceContentDelayTimer
                    interval: 100
                    repeat: false
                    onTriggered: root.workspaceContentReady = root.contentShown
                }

                onContentShownChanged: {
                    if (contentShown) workspaceContentDelayTimer.restart();
                    else {
                        workspaceContentDelayTimer.stop();
                        workspaceContentReady = false;
                    }
                }

                Connections {
                    target: overviewScope
                    function onSetSearchingTextRequested(text) {
                        root.setSearchingText(text);
                    }
                }


                function setSearchingText(text) {
                    searchWidget.setSearchingText(text);
                    searchWidget.focusFirstItem();
                }

                Item {
                    id: contentItem
                    anchors.fill: parent
                    opacity: root.contentShown && searchWidget.backdropReady ? 1 : 0

                    MouseArea { // We could have used PanelWindow.mask to detect this, but this is more stable
                        anchors.fill: parent
                        onClicked: GlobalStates.overviewOpen = false;
                    }

                    Item { // Wrapper for animation 
                        id: searchWidgetWrapper
                        width: searchWidget.implicitWidth
                        height: searchWidget.implicitHeight
                        z: 999

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                GlobalStates.overviewOpen = false;
                            }
                        }

                        anchors.centerIn: parent
                        SearchWidget {
                            id: searchWidget
                            scale: root.launcherScale
                            transformOrigin: Item.Center
                            anchors.centerIn: parent
                            Synchronizer on searchingText {
                                property alias source: root.searchingText
                            }
                        }
                    }
                    

                    Loader { // Classic overview
                        id: overviewLoader
                        scale: root.effectiveScale
                        anchors.top: searchWidgetWrapper.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        active: root.contentShown && root.workspaceContentReady && root.showWorkspaceOverview && (Config?.options.overview.enable ?? true) && !root.isScrollingLayout
                        sourceComponent: OverviewWidget {
                            panelWindow: root
                            visible: root.showWorkspaceOverview
                            monitorIndex: root.monitorIndex
                        }
                    }

                    Loader { // Scrolling overview
                        id: scrollingOverviewLoader
                        scale: root.effectiveScale
                        anchors.fill: parent
                        active: root.contentShown && root.workspaceContentReady && root.showWorkspaceOverview && (Config?.options.overview.enable ?? true) && root.isScrollingLayout
                        sourceComponent: ScrollingOverviewWidget {
                            anchors.fill: parent
                            panelWindow: root
                            visible: root.showWorkspaceOverview
                            monitorIndex: root.monitorIndex
                        }
                    }
                }   
            }   
        }
    }
    
    

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        overviewScope.setSearchingTextRequested(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        overviewScope.setSearchingTextRequested(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
