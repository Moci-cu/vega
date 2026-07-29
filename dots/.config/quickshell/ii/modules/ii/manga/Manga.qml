import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    signal toggleRequested()
    signal fullscreenRequested()
    property string pendingAction: ""

    function dispatch(action) {
        if (!mangaPanelLoader.active || !mangaPanelLoader.item) {
            pendingAction = action
            mangaPanelLoader.active = true
            return
        }
        if (action === "fullscreen")
            mangaPanelLoader.item.toggleFullscreen()
        else
            mangaPanelLoader.item.togglePanel()
    }

    readonly property var focusedScreen: {
        const focused = Hyprland.focusedMonitor
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i]
            if (focused && screen.name === focused.name)
                return screen
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    readonly property int screenW: focusedScreen ? focusedScreen.width : 1920
    readonly property int screenH: focusedScreen ? focusedScreen.height : 1080

    FloatingWindow {
        id: mangaWindow

        readonly property var panel: mangaPanelLoader.item

        visible: panel ? panel.panelOpen || panel.animRunning : false
        color: "transparent"
        screen: root.focusedScreen
        fullscreen: panel ? panel.isFullscreen : false
        implicitWidth: panel ? panel.normalPanelWidth : Math.min(root.screenW - 48, 1080)
        implicitHeight: panel ? panel.normalPanelHeight : Math.min(root.screenH - 48, 820)
        minimumSize: panel && panel.isFullscreen
            ? Qt.size(1, 1)
            : Qt.size(implicitWidth, implicitHeight)
        maximumSize: panel && panel.isFullscreen
            ? Qt.size(root.screenW, root.screenH)
            : Qt.size(implicitWidth, implicitHeight)
        title: "Manga Reader"

        Loader {
            id: mangaPanelLoader
            anchors.fill: parent
            active: false
            sourceComponent: MangaPanel {
                screenW: root.screenW
                screenH: root.screenH
            }
            onLoaded: {
                var action = root.pendingAction
                root.pendingAction = ""
                root.dispatch(action || "toggle")
            }
        }

        Connections {
            target: root

            function onToggleRequested() {
                root.dispatch("toggle")
            }

            function onFullscreenRequested() {
                root.dispatch("fullscreen")
            }
        }
    }

    IpcHandler {
        target: "manga"

        function toggle() {
            root.toggleRequested()
        }

        function toggleFullscreen() {
            root.fullscreenRequested()
        }
    }

    GlobalShortcut {
        name: "mangaToggle"
        description: "Toggles manga reader"

        onPressed: root.toggleRequested()
    }
}
