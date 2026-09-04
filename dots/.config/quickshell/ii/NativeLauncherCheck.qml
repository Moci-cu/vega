import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.ii.overview

ShellRoot {
    id: root

    property int attempts: 0
    property bool searchStarted: false
    property bool searchFinished: false
    property bool actionReady: false
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
            root.searchFinished = true;
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
                if (root.searchFinished && root.actionReady) {
                    checkTimer.stop();
                    Qt.exit(0);
                    return;
                }
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

            const bluetoothAction = LauncherSearch.commandKeywordResult("open blue");
            const bluetoothIntent = LauncherSearch.commandKeywordResult("enable b");
            const bluetoothTypo = LauncherSearch.commandKeywordResult("open bluetoth");
            const nightAction = LauncherSearch.commandKeywordResult("Night Mode");
            const openIntent = LauncherSearch.commandKeywordResult("open");
            const reorderedAction = LauncherSearch.commandKeywordResult("turn bluetooth of");
            const scanIntent = LauncherSearch.commandKeywordResult("sc");
            const startIntent = LauncherSearch.commandKeywordResult("sta");
            const turnOffIntent = LauncherSearch.commandKeywordResult("turn off");
            const wifiAction = LauncherSearch.commandKeywordResult("turn on wi");
            const wifiTypo = LauncherSearch.commandKeywordResult("wfi");
            const timerAction = LauncherSearch.commandKeywordResult("set a timer for 60 minutes");
            const timerSuggestion = LauncherSearch.commandKeywordResult("set timer for 60");
            const timerHours = LauncherSearch.commandKeywordResult("start timer for 2 hours");
            if (bluetoothAction?.key !== "command-keyword:bluetooth-open"
                    || !bluetoothAction.completeOnly
                    || bluetoothIntent?.key !== "command-keyword:bluetooth-on"
                    || bluetoothTypo?.key !== "command-keyword:bluetooth-open"
                    || !["command-keyword:wifi-open", "command-keyword:bluetooth-open"].includes(openIntent?.key)
                    || reorderedAction?.key !== "command-keyword:bluetooth-off"
                    || !["command-keyword:wifi-off", "command-keyword:bluetooth-off"].includes(turnOffIntent?.key)
                    || wifiAction?.key !== "command-keyword:wifi-on"
                    || wifiTypo?.key !== "command-keyword:wifi"
                    || timerAction?.key !== "command-keyword:timer-set"
                    || timerAction.durationMinutes !== 60
                    || timerAction.completeOnly
                    || timerSuggestion?.completionName !== "set timer for 60 minutes"
                    || timerSuggestion.durationMinutes !== 60
                    || timerHours?.durationMinutes !== 120
                    || !["scan wifi", "scan bluetooth"].includes(scanIntent?.completionName)
                    || !["start wifi", "start bluetooth"].includes(startIntent?.completionName)
                    || LauncherSearch.commandKeywordResult("start blu")?.completionName !== "start bluetooth"
                    || LauncherSearch.commandKeywordResult("caffe")?.completionName !== "caffeine"
                    || LauncherSearch.commandKeywordResult("open kitty") !== null
                    || LauncherSearch.isApplicationQuery("enable bluetooth")
                    || !LauncherSearch.isApplicationQuery(">open bluetooth")
                    || !LauncherSearch.isApplicationQuery("bluetooth")
                    || LauncherSearch.naturalTokens("Turn Wi-Fi off!").join(" ") !== "turn wifi off"
                    || LauncherSearch.appAutocompleteCompletion({ name: "CachyOS Kernel Manager" }, "kernel")
                        !== " Manager"
                    || LauncherSearch.appAutocompleteCompletion({ name: "CachyOS Hello" }, "hello")
                        !== " → CachyOS Hello"
                    || nightAction?.key !== "command-keyword:night-mode"
                    || nightAction.completeOnly)
                return root.fail("launcher command keyword completion was classified incorrectly");

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
            root.attempts = 0;
            root.searchStarted = true;
            GlobalStates.overviewOpen = true;
            widgetLoader.item.runAfterResultsRefresh("her", function() {
                if (!root.searchFinished)
                    return root.fail("query action ran before the latest results were ready");
                if (widgetLoader.item.nativeAutocompleteResult?.id !== root.expectedId)
                    return root.fail("compact searchbar did not refresh its native autocomplete result");
                root.actionReady = true;
            });
        }
    }
}
