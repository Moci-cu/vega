import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions

/*
    Almost all of the custom color schemes (latte.json, samurai.json etc.) are gotten from https://github.com/snowarch/quickshell-ii-niri/blob/main/modules/common/ThemePresets.qml

    To add a new custom color scheme:

    1. Get a proper color scheme (in the same format as the default ones) and put in to ~/.config/illogical_impulse/themes
    2. Add the exact name of the json file to the config.json - appearance - customColorSchemes
*/

GridLayout {
    id: root
    implicitWidth: parent.width
    columns: 3

    readonly property list<string> builtInColorSchemes: ["angel_light", "angel", "ayu", "cobalt2", "cursor", "dracula", "flexoki", "frappe", "github", "gruvbox", "kanagawa", "latte", "macchiato", "material_ocean", "matrix", "mercury", "mocha", "nord", "open_code", "orng", "osaka_jade", "rose_pine", "sakura", "samurai", "synthwave84", "vercel", "vesper", "zen_burn", "zen_garden"]
    property list<string> customColorSchemes: Config.options.appearance.customColorSchemes ?? []

    readonly property list<string> wallpaperColorSchemes: ["scheme-auto", "scheme-content", "scheme-tonal-spot", "scheme-fidelity", "scheme-fruit-salad", "scheme-expressive", "scheme-rainbow", "scheme-neutral", "scheme-monochrome"]

    property bool customTheme: false
    property bool builtInTheme: false
    property int startDelay: 0
    property int loadInterval: 80
    property list<string> colorSchemes: customTheme ? customColorSchemes : builtInTheme ? builtInColorSchemes : root.wallpaperColorSchemes
    property var previewResults: ({})
    property Process wallpaperPreviewProcess: null

    readonly property bool wallpaperTheme: !customTheme && !builtInTheme
    readonly property string wallpaperPath: Config.options.background.wallpaperPath
    readonly property string materialPreviewScript: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/generate_colors_material.py`)

    function formatText(text) {
        if (customTheme || builtInTheme) return text.charAt(0).toUpperCase() + text.slice(1);
        const sliced = text.split("-").slice(1).join(" ");
        return sliced.charAt(0).toUpperCase() + sliced.slice(1);
    }

    property int loadedCount: 0

    function resetLoadingState() {
        startTimer.stop()
        loadTimer.stop()
        root.stopWallpaperPreview()
        root.loadedCount = 0
        root.previewResults = ({})
    }

    function scheduleLoading() {
        root.resetLoadingState()
        startTimer.start()
    }

    function stopWallpaperPreview() {
        const process = root.wallpaperPreviewProcess
        root.wallpaperPreviewProcess = null
        if (!process) return
        if (process.running) process.running = false
        else process.destroy()
    }

    function startWallpaperPreview(path) {
        root.stopWallpaperPreview()
        root.wallpaperPreviewProcess = wallpaperPreviewProcessComponent.createObject(root, {
            "requestPath": path
        })
    }

    Repeater {
        model: root.colorSchemes
        
        delegate: ColorPreviewButton {
            Layout.fillWidth: true
            
            colorScheme: modelData
            colorSchemeDisplayName: formatText(modelData)
            customTheme: root.customTheme
            builtInTheme: root.builtInTheme
            previewData: root.previewResults[modelData] ?? null
            
            shouldLoad: index < root.loadedCount
        }
    }

    Component {
        id: wallpaperPreviewProcessComponent

        Process {
            id: previewProcess
            required property string requestPath
            running: true
            command: [root.materialPreviewScript, "--path", requestPath, "--preview-all"]

            stdout: StdioCollector {
                onStreamFinished: {
                    if (root.wallpaperPreviewProcess !== previewProcess || previewProcess.requestPath !== root.wallpaperPath) return
                    try {
                        root.previewResults = JSON.parse(this.text || "{}")
                        root.loadedCount = root.colorSchemes.length
                    } catch (e) {
                        console.log("[ColorPreviewGrid] Batch preview parse error:", this.text)
                    }
                }
            }

            onExited: {
                if (root.wallpaperPreviewProcess === previewProcess) root.wallpaperPreviewProcess = null
                destroy()
            }
        }
    }

    Timer {
        id: loadTimer
        interval: root.loadInterval
        repeat: true
        running: false
        
        onTriggered: {
            root.loadedCount += 1

            if (root.loadedCount >= root.colorSchemes.length) { // stop it after all are loaded
                loadTimer.stop()
            }
        }
    }

    Timer {
        id: startTimer
        interval: root.startDelay
        repeat: false
        running: false
        onTriggered: {
            if (root.wallpaperTheme) {
                if (root.wallpaperPath === "") return
                root.startWallpaperPreview(root.wallpaperPath)
                return
            }
            loadTimer.start()
        }
    }

    onColorSchemesChanged: Qt.callLater(root.scheduleLoading)
    onWallpaperPathChanged: if (root.wallpaperTheme) Qt.callLater(root.scheduleLoading)

    Component.onCompleted: Qt.callLater(root.scheduleLoading)
}
