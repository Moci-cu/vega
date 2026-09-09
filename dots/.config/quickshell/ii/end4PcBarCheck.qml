pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs
import qs.modules.common
import qs.modules.ii.bar

ShellRoot {
    id: root
    property var names: ["BarContent", "LauncherButton", "Workspaces", "Media", "Visualizer", "DocktoPanel", "SysTray", "PowerButton", "SystemIcons", "Resources", "BatteryIndicator", "UpdatesCount", "ClockWidget"]
    property var instances: []
    property int initialResources: 0
    property int initialSpectrum: 0
    property int toggles: 0
    property int nexts: 0
    property int previous: 0
    property var editor
    readonly property bool configReady: Config.ready
    function assert(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); } }

    PanelWindow {
        id: window
        visible: false
        implicitWidth: 1920
        implicitHeight: 40
        Item { id: host; anchors.fill: parent }
    }
    Timer {
        interval: 1500; running: root.configReady
        onTriggered: {
            root.assert(Config.ready, "Config readiness");
            root.initialResources = ResourceUsage.activeInstances;
            root.initialSpectrum = End4PcSpectrum.users;
            const editorComponent = Qt.createComponent("modules/settings/BarConfig.qml");
            root.assert(editorComponent.status === Component.Ready, editorComponent.errorString());
            root.editor = editorComponent.createObject(host, {register: false});
            root.assert(root.editor !== null, "layout editor instantiated");
            for (const path of ["modules/ii/bar/Bar.qml", "modules/ii/verticalBar/VerticalBar.qml", "modules/settings/BarConfig.qml"]) {
                const component = Qt.createComponent(path);
                root.assert(component.status === Component.Ready, path + ": " + component.errorString());
            }
            for (const name of root.names) {
                const component = Qt.createComponent("modules/ii/bar/end4pc/" + name + ".qml");
                root.assert(component.status === Component.Ready, name + ": " + component.errorString());
                const item = component.createObject(host);
                root.assert(item !== null, name + " instantiated");
                if (name === "BarContent") item.width = 1920;
                root.instances.push(item);
            }
            settle.start();
        }
    }
    Timer {
        id: settle
        interval: 2500
        onTriggered: {
            for (let i = 0; i < root.instances.length; i++) {
                const item = root.instances[i];
                root.assert(Number.isFinite(item.implicitWidth) && item.implicitWidth >= 0, root.names[i] + " finite width");
                if (root.names[i] !== "SysTray") root.assert(item.implicitHeight > 0, root.names[i] + " positive height");
            }
            const frames = End4PcSpectrum.parseFrame("12;nan;-5;1200;;40;");
            root.assert(JSON.stringify(frames) === "[12,0,1000,40]", "Cava frame validation");
            root.assert(End4PcSpectrum.users > root.initialSpectrum, "visualizer acquired");
            root.assert(ResourceUsage.activeInstances > root.initialResources, "resource polling acquired");
            const bar = root.instances[0];
            root.assert(bar.pillColor("resources").toString() === "transparent", "metric group has no highlight");
            bar.leftLayout = ["active_window", "weather", "bongocat"];
            bar.vertical = true;
            bar.width = 56;
            bar.height = 1080;
            const dock = root.instances[root.names.indexOf("DocktoPanel")];
            dock._startPinnedItemDrag(0);
            root.assert(dock.dragging && dock.suppressClick, "dock drag suppresses launch");
            dock._cancelPinnedDrag();
            root.assert(!dock.dragging, "dock drag cancellation");
            const media = root.instances[root.names.indexOf("Media")];
            media.activePlayer = null;
            root.assert(!media.control("toggle") && !media.control("next"), "no player is safe");
            media.activePlayer = {
                canControl: true, canTogglePlaying: true, canGoNext: false, canGoPrevious: true,
                isPlaying: false, trackTitle: "Long track title ".repeat(30), trackArtist: "Artist",
                togglePlaying: () => root.toggles++, next: () => root.nexts++, previous: () => root.previous++
            };
            root.assert(media.control("toggle") && root.toggles === 1, "play/pause routes to player");
            root.assert(!media.control("next") && root.nexts === 0, "unsupported next rejected");
            root.assert(media.control("previous") && root.previous === 1, "previous routes to player");
            End4PcSpectrum.player = {isPlaying: true};
            audioCheck.start();
        }
    }
    Timer {
        id: audioCheck
        interval: 2000
        onTriggered: {
            root.assert(End4PcSpectrum.running, "real Cava started");
            root.assert(End4PcSpectrum.points.length > 0, "real Cava frames received");
            root.assert(End4PcSpectrum.error === "", "Cava backend clean: " + End4PcSpectrum.error);
            const media = root.instances[root.names.indexOf("Media")];
            root.assert(media.implicitWidth > 0 && media.implicitWidth < 300, "long media title bounded");
            GlobalStates.screenLocked = true;
            lockCheck.start();
        }
    }
    Timer {
        id: lockCheck
        interval: 500
        onTriggered: {
            root.assert(!End4PcSpectrum.running && End4PcSpectrum.points.length === 0, "lock stops Cava and clears frames");
            GlobalStates.screenLocked = false;
            End4PcSpectrum.player = null;
            for (const item of root.instances) item.destroy();
            root.editor.destroy();
            release.start();
        }
    }
    Timer {
        id: release
        interval: 250
        onTriggered: {
            root.assert(End4PcSpectrum.users === root.initialSpectrum, "spectrum released");
            root.assert(ResourceUsage.activeInstances === root.initialResources, "polling released");
            root.assert(!End4PcSpectrum.running, "no listeners stops Cava");
            console.log("PASS: end4-pC loading, dimensions, media capabilities, real Cava frames, lock and release");
            Qt.quit();
        }
    }
}
