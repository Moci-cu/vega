import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.overview

ShellRoot {
    id: root
    property int phase: 0
    property int attempts: 0
    property int baseline: 0

    function fail(message) {
        console.error("[SystemMetricsCheck] " + message);
        Qt.exit(1);
    }

    Loader {
        id: launcher
        active: Config.ready
        sourceComponent: SearchWidget {
            revealProgress: 0
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (++root.attempts > 100) return root.fail("timed out");
            if (launcher.status === Loader.Error) return root.fail("launcher failed to load");
            if (launcher.status !== Loader.Ready) return;
            const widget = launcher.item;
            if (root.phase === 0) {
                const entry = LauncherSearch.commandKeywordResult("metrics");
                if (entry?.key !== "command-keyword:metrics" || !entry.keepLauncherOpen)
                    return root.fail("metrics suggestion missing");
                root.baseline = ResourceUsage.activeInstances;
                GlobalStates.overviewOpen = true;
                widget.showMetrics = true;
                root.phase++;
            } else if (root.phase === 1) {
                if (!widget.controlPanelOpen || !widget.resultsVisible
                        || widget.activeResultCount !== 0
                        || widget.resultsPanelWidth !== 794 || widget.activeResultsPanelHeight !== 440
                        || ResourceUsage.activeInstances !== root.baseline + 1)
                    return root.fail(`metrics state: control=${widget.controlPanelOpen}, results=${widget.resultsVisible}, count=${widget.activeResultCount}, size=${widget.resultsPanelWidth}x${widget.activeResultsPanelHeight}, subscribers=${ResourceUsage.activeInstances}, baseline=${root.baseline}`);
                for (const query of ["kitty", "wifi", "33"])
                    widget.setSearchingText(query);
                root.phase++;
            } else if (root.phase === 2) {
                if (!widget.showMetrics || widget.searchingText !== ""
                        || widget.calculatorActive || widget.wifiCommandMode
                        || widget.activeResultCount !== 0
                        || ResourceUsage.activeInstances !== root.baseline + 1)
                    return root.fail("metrics accepted a search or activated another mode");
                root.phase++;
            } else if (root.phase === 3) {
                GlobalStates.overviewOpen = false;
                root.phase++;
            } else {
                if (ResourceUsage.activeInstances !== root.baseline)
                    return root.fail("closing leaked resource polling");
                console.log("[SystemMetricsCheck] PASS: suggestion, grid size, read-only metrics, polling cleanup");
                Qt.exit(0);
            }
        }
    }
}
