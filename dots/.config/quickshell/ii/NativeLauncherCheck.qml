import QtQuick
import Quickshell
import qs.services
import qs.modules.common
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
            if (!first?.nativeApp || first.id !== root.expectedId || !first.iconName
                    || NativeAppSearch.model.count < 1)
                return root.fail("'her' did not return Heroic Games Launcher with an icon");
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
            if (root.searchStarted) {
                if (++root.attempts >= 300)
                    return root.fail("search did not finish in time");
                return;
            }
            if (widgetLoader.status !== Loader.Ready || !NativeAppSearch.available || !NativeAppSearch.model?.indexReady) {
                if (++root.attempts >= 150)
                    return root.fail("launcher widget, native backend, or application index timed out");
                return;
            }
            if (!widgetLoader.item.appMode
                    || widgetLoader.item.appGridColumns !== 7
                    || widgetLoader.item.appGridRows !== 4
                    || widgetLoader.item.searchPillWidth >= widgetLoader.item.resultsPanelWidth
                    || !LauncherSearch.shouldUseNativeAppSearch(""))
                return root.fail("launcher did not enter the detached 7x4 application layout");

            const entry = Array.from(DesktopEntries.applications.values)
                .find(app => String(app.name).toLowerCase().startsWith("heroic"));
            if (!entry)
                return root.fail("Heroic Games Launcher is not installed");
            root.expectedId = entry.id || entry.name;
            root.searchStarted = true;
            GlobalStates.overviewOpen = true;
            LauncherSearch.query = "her";
        }
    }
}
