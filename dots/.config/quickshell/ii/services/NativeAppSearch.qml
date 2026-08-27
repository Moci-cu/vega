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
            entries.push({
                id: app.id || app.name,
                name: app.name,
                iconName: app.icon
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
        onLoaded: root.rebuildIndex()
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            Qt.callLater(root.rebuildIndex);
        }
    }
}
