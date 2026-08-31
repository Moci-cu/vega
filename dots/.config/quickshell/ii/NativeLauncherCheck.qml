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
                    || widgetLoader.item.clipboardVisibleRowLimit !== 8
                    || widgetLoader.item.clipboardPanelHeight !== 518
                    || widgetLoader.item.appGridCellWidth !== 110
                    || widgetLoader.item.appGridCellHeight !== 104
                    || widgetLoader.item.resultsPanelWidth !== 794
                    || widgetLoader.item.resultsPanelHeight !== 440
                    || widgetLoader.item.categoryEntries.length !== 4
                    || widgetLoader.item.categoryPanelWidth !== 490
                    || widgetLoader.item.categoryPanelHeight !== 184
                    || widgetLoader.item.searchPillWidth !== 490
                    || widgetLoader.item.searchPillHeight !== 90
                    || widgetLoader.item.searchPillWidth >= widgetLoader.item.resultsPanelWidth
                    || widgetLoader.item.showResults
                    || widgetLoader.item.showCategories
                    || widgetLoader.item.showClipboard
                    || widgetLoader.item.clipboardMode
                    || widgetLoader.item.categoriesVisible
                    || widgetLoader.item.implicitHeight >= widgetLoader.item.resultsPanelHeight
                    || !LauncherSearch.shouldUseNativeAppSearch(""))
                return root.fail("launcher did not keep the compact default with a detached 7x4 application layout");

            const clipboardImage = Cliphist.presentation("1\t[[ binary data 10 KiB png 64x32 ]]");
            if (clipboardImage.title !== "Image 64×32"
                    || !clipboardImage.subtitle.startsWith("PNG · 10 KiB · ")
                    || clipboardImage.icon !== "image")
                return root.fail("clipboard image presentation exposed raw binary data");

            if (LauncherSearch.mathExpression("-23 + 12") !== "-23 + 12"
                    || LauncherSearch.isApplicationQuery("-23 + 12"))
                return root.fail("negative leading number was not classified as calculator input");

            if (widgetLoader.item.retainedBackdropWidth < widgetLoader.item.resultsPanelWidth
                    || widgetLoader.item.retainedBackdropHeight
                        < widgetLoader.item.searchPillHeight + widgetLoader.item.searchPanelGap
                            + widgetLoader.item.clipboardPanelHeight)
                return root.fail("launcher backdrop was not preallocated for its largest mode");

            widgetLoader.item.showCategories = true;
            if (!widgetLoader.item.categoriesVisible)
                return root.fail("launcher category panel did not expose its four-category state");
            widgetLoader.item.showCategories = false;

            const entry = Array.from(DesktopEntries.applications.values)
                .find(app => String(app.name).toLowerCase().startsWith("heroic"));
            if (!entry)
                return root.fail("Heroic Games Launcher is not installed");
            root.expectedId = entry.id || entry.name;
            root.searchStarted = true;
            GlobalStates.overviewOpen = true;
            widgetLoader.item.showResults = true;
            LauncherSearch.query = "her";
        }
    }
}
