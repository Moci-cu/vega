import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    signal toggleRequested()

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

        visible: mangaPanel.panelOpen || mangaPanel.animRunning
        color: "transparent"
        implicitWidth: mangaPanel.panelWidth
        implicitHeight: mangaPanel.panelHeight
        title: "Manga Reader"

        MangaPanel {
            id: mangaPanel
            anchors.fill: parent
            screenW: root.screenW
            screenH: root.screenH
        }

        Connections {
            target: root

            function onToggleRequested() {
                mangaPanel.togglePanel()
            }
        }
    }

    IpcHandler {
        target: "manga"

        function toggle() {
            root.toggleRequested()
        }
    }

    GlobalShortcut {
        name: "mangaToggle"
        description: "Toggles manga reader"

        onPressed: root.toggleRequested()
    }
}
