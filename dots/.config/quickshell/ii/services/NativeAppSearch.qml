pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var model: backendLoader.item
    readonly property bool available: backendLoader.status === Loader.Ready && root.model !== null

    function rebuildIndex() {
        if (!root.available)
            return;

        const apps = Array.from(DesktopEntries.applications.values);
        const entries = [];
        for (const app of apps) {
            const id = app.id || app.name;
            entries.push({
                id: id,
                name: app.name,
                iconName: app.icon,
                usageBonus: AppSearch.launcherUsageBonus(`app:${id}`)
            });
        }
        root.model.rebuildIndex(entries);
    }

    function search(query, limit, fallbackRows) {
        if (root.available)
            root.model.search(query, limit, fallbackRows ?? []);
    }

    function clear() {
        if (root.available)
            root.model.clear();
    }

    function get(row) {
        return root.available ? root.model.get(row) : null;
    }

    Loader {
        id: backendLoader
        source: Quickshell.shellPath("native/NativeAppSearchBackend.qml")
        onLoaded: indexRebuildTimer.restart()
    }

    Timer {
        id: indexRebuildTimer
        interval: 50
        onTriggered: root.rebuildIndex()
    }

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            indexRebuildTimer.restart();
        }
    }

    Connections {
        target: AppSearch

        function onUsageRevisionChanged() {
            indexRebuildTimer.restart();
        }
    }
}
