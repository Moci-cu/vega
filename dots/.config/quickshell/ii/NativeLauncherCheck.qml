import QtQuick
import Quickshell
import qs.services
import qs.modules.ii.overview

ShellRoot {
    id: root

    property int attempts: 0
    property bool searchStarted: false
    property string expectedId: ""

    function fail(message) {
        checkTimer.stop();
        console.error(`[NativeLauncherCheck] ${message}`);
        Qt.exit(1);
    }

    Connections {
        target: NativeAppSearch.model
        ignoreUnknownSignals: true

        function onSearchFinished() {
            if (!root.searchStarted)
                return;
            const first = NativeAppSearch.get(0);
            if (!first?.nativeApp || first.id !== root.expectedId)
                return root.fail("native model returned the wrong application");
            console.log(`[NativeLauncherCheck] first=${first.name} count=${NativeAppSearch.model.count}`);
            Qt.exit(0);
        }
    }

    Loader {
        id: widgetLoader
        active: true
        sourceComponent: SearchWidget {}
    }

    Timer {
        id: checkTimer
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (widgetLoader.status === Loader.Error)
                return root.fail("launcher widget failed to load");
            if (widgetLoader.status !== Loader.Ready || !NativeAppSearch.available || !NativeAppSearch.model?.indexReady) {
                if (++root.attempts >= 150)
                    return root.fail("launcher widget, native backend, or application index timed out");
                return;
            }
            if (root.searchStarted)
                return;

            const entry = Array.from(DesktopEntries.applications.values)[0];
            if (!entry)
                return root.fail("desktop application index is empty");
            root.expectedId = entry.id || entry.name;
            root.searchStarted = true;
            LauncherSearch.query = entry.name;
        }
    }
}
