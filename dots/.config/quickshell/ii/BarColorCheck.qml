import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.ii.bar as Bar
import qs.services

ShellRoot {
    id: root
    property int attempts: 0

    function fail(message) {
        checkTimer.stop();
        console.error(`[BarColorCheck] ${message}`);
        Qt.exit(1);
    }

    Loader {
        id: systemMonitorLoader
        width: 280
        height: 36
        sourceComponent: Bar.BarComponent {
            modelData: ({ id: "system_monitor", visible: true })
            index: 0
            list: [modelData]
            barSection: 2
            screen: Quickshell.screens[0]
            parallaxWorkspaceValue: 0.3
            parallaxSidebarBalance: 0
        }
    }

    Component.onCompleted: {
        LyricsService.mediaModeOpenCount = 1;
        const mediaForeground = Appearance.barForegroundAt(0, null, 1, 0);
        LyricsService.mediaModeOpenCount = 0;
        if (!Qt.colorEqual(mediaForeground, "#F5F5F5"))
            return root.fail("Media mode foreground is not near-white");

        const dark = Qt.color("#171717");
        const light = Qt.color("#F5F5F5");
        const onLight = ColorUtils.getContrastPalette(["#d8eeff"]);
        const onDark = ColorUtils.getContrastPalette(["#16131d"]);
        const mixedSamples = ["#ffffff", "#f5e8d6", "#101010", "#050505", "#ead2b7"];
        const mixedPatch = ColorUtils.getContrastPalette(mixedSamples);
        const darkMinimum = Math.min(...mixedSamples.map(color => ColorUtils.getContrastRatio(dark, color)));
        const lightMinimum = Math.min(...mixedSamples.map(color => ColorUtils.getContrastRatio(light, color)));

        if (!Qt.colorEqual(onLight.foreground, dark) || !Qt.colorEqual(onDark.foreground, light))
            return root.fail("Adaptive monochrome selection failed");
        if (!Qt.colorEqual(mixedPatch.foreground, darkMinimum >= lightMinimum ? dark : light)
                || Math.abs(mixedPatch.minimumContrast - Math.max(darkMinimum, lightMinimum)) > 0.0001)
            return root.fail("Worst-case contrast selection failed");
        if (Appearance.barWorkspaceValue(1) !== 0.1 || Appearance.barWorkspaceValue(10) !== 1 || Appearance.barWorkspaceValue(11) !== 0.1)
            return root.fail("Workspace parallax normalization failed");

        console.log(`[BarColorCheck] onLight=${onLight.foreground} onDark=${onDark.foreground} mixed=${mixedPatch.foreground}`);
    }

    Timer {
        id: checkTimer
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (Appearance.wallpaperSampleWidth <= 1) {
                if (++root.attempts >= 50) return root.fail("Wallpaper color sampler timed out");
                return;
            }

            const expected = Appearance.barSampleColumns * Appearance.barSampleRows;
            if (Appearance.barSampleRows <= 1 || Appearance.barBackgroundSamples.length !== expected)
                return root.fail("Wallpaper color sampler is not a 2D grid");

            const screen = ({ width: 1920, height: 1080 });
            const startPalette = Appearance.barPaletteAt(960, 48, screen, 0.1, 0);
            const endPalette = Appearance.barPaletteAt(960, 48, screen, 0.9, 0);
            const startRect = Appearance.barWallpaperSourceRect(100, 4, 200, 52, screen, 0.1, 0);
            const endRect = Appearance.barWallpaperSourceRect(100, 4, 200, 52, screen, 0.9, 0);
            if (startPalette.sampleCount !== 5 || endPalette.sampleCount !== 5)
                return root.fail("Bar palette is not using a five-point patch");
            if (startPalette.centerColumn === endPalette.centerColumn)
                return root.fail("Parallax progress did not move the wallpaper sample");
            if (startRect.x === endRect.x || startRect.width <= 0 || startRect.height <= 0)
                return root.fail("Liquid glass wallpaper crop did not follow parallax");
            if (systemMonitorLoader.status !== Loader.Ready || !systemMonitorLoader.item)
                return root.fail("Adaptive system monitor failed to load");
            if (Appearance.colors.transparentBar && systemMonitorLoader.item.colBackground.a !== 0)
                return root.fail("Transparent bar component retained a background");

            console.log(`[BarColorCheck] samples=${Appearance.barSampleColumns}x${Appearance.barSampleRows} columns=${startPalette.centerColumn}->${endPalette.centerColumn}`);
            Qt.exit(0);
        }
    }
}
