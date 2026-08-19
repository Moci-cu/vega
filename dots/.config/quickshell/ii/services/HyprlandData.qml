pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    property bool clientsDirty: false
    property bool monitorsDirty: false
    property bool layersDirty: false
    property bool workspacesDirty: false
    property bool activeWorkspaceDirty: false

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        root.requestRefresh({ clients: true });
    }

    function updateLayers() {
        root.requestRefresh({ layers: true });
    }

    function updateMonitors() {
        root.requestRefresh({ monitors: true });
    }

    function updateWorkspaces() {
        root.requestRefresh({ workspaces: true, activeWorkspace: true });
    }

    function updateActiveWorkspace() {
        root.requestRefresh({ activeWorkspace: true });
    }

    function updateAll() {
        root.requestRefresh({
            clients: true,
            monitors: true,
            layers: true,
            workspaces: true,
            activeWorkspace: true
        });
    }

    function requestRefresh(categories) {
        if (categories.clients) root.clientsDirty = true;
        if (categories.monitors) root.monitorsDirty = true;
        if (categories.layers) root.layersDirty = true;
        if (categories.workspaces) root.workspacesDirty = true;
        if (categories.activeWorkspace) root.activeWorkspaceDirty = true;
        if (!refreshCoalesceTimer.running) refreshCoalesceTimer.start();
    }

    function flushRefreshes() {
        if (root.clientsDirty && !getClients.running) {
            root.clientsDirty = false;
            getClients.running = true;
        }
        if (root.monitorsDirty && !getMonitors.running) {
            root.monitorsDirty = false;
            getMonitors.running = true;
        }
        if (root.layersDirty && !getLayers.running) {
            root.layersDirty = false;
            getLayers.running = true;
        }
        if (root.workspacesDirty && !getWorkspaces.running) {
            root.workspacesDirty = false;
            getWorkspaces.running = true;
        }
        if (root.activeWorkspaceDirty && !getActiveWorkspace.running) {
            root.activeWorkspaceDirty = false;
            getActiveWorkspace.running = true;
        }
    }

    function handleHyprlandEvent(eventName) {
        switch (eventName) {
        case "activewindow":
        case "activewindowv2":
        case "windowtitle":
        case "windowtitlev2":
        case "fullscreen":
        case "changefloatingmode":
        case "urgent":
        case "minimize":
        case "togglegroup":
        case "moveintogroup":
        case "moveoutofgroup":
        case "pin":
            root.requestRefresh({ clients: true });
            break;
        case "openwindow":
        case "closewindow":
        case "movewindow":
        case "movewindowv2":
            root.requestRefresh({ clients: true, workspaces: true });
            break;
        case "workspace":
        case "workspacev2":
        case "focusedmon":
        case "focusedmonv2":
        case "activespecial":
        case "activespecialv2":
            root.requestRefresh({ monitors: true, activeWorkspace: true });
            break;
        case "createworkspace":
        case "createworkspacev2":
        case "destroyworkspace":
        case "destroyworkspacev2":
            root.requestRefresh({ monitors: true, workspaces: true, activeWorkspace: true });
            break;
        case "moveworkspace":
        case "moveworkspacev2":
        case "renameworkspace":
            root.requestRefresh({ clients: true, monitors: true, workspaces: true, activeWorkspace: true });
            break;
        case "monitoradded":
        case "monitoraddedv2":
        case "monitorremoved":
        case "monitorremovedv2":
            root.requestRefresh({ clients: true, monitors: true, workspaces: true, activeWorkspace: true });
            break;
        case "openlayer":
        case "closelayer":
            root.requestRefresh({ layers: true });
            break;
        case "activelayout":
        case "submap":
        case "screencast":
        case "bell":
            break;
        case "configreloaded":
        default:
            root.updateAll();
            break;
        }
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        updateAll();
    }

    Timer {
        id: refreshCoalesceTimer
        interval: 16
        repeat: false
        onTriggered: root.flushRefreshes()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            root.handleHyprlandEvent(event.name);
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        onExited: {
            if (root.clientsDirty) refreshCoalesceTimer.restart();
        }
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        onExited: {
            if (root.monitorsDirty) refreshCoalesceTimer.restart();
        }
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        onExited: {
            if (root.layersDirty) refreshCoalesceTimer.restart();
        }
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        onExited: {
            if (root.workspacesDirty) refreshCoalesceTimer.restart();
        }
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                // Filter out invalid workspace ids (e.g. lock-screen temp workspace 2147483647 - N)
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        onExited: {
            if (root.activeWorkspaceDirty) refreshCoalesceTimer.restart();
        }
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
            }
        }
    }
}
