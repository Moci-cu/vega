import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
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

    StyledText {
        id: contrastFallbackText
        visible: false
        haloEnabled: true
        text: "Aa"
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
        if (!Qt.colorEqual(mediaForeground, "#FFFFFF"))
            return root.fail("Media mode foreground is not white");

        const onLight = ColorUtils.getTonalForeground("#d8eeff", "#6750a4");
        const onDark = ColorUtils.getTonalForeground("#16131d", "#d0bcff");
        const onMid = ColorUtils.getTonalForeground("#6b72a9", "#6750a4");
        const onGray = ColorUtils.getTonalForeground("#eeeeee", "#6750a4");
        const onOrange = ColorUtils.getTonalForeground("#c08859", "#6750a4");
        const stablePatch = ColorUtils.getTonalPalette("#f2dfc8", ["#f2dfc8", "#f5e8d6", "#101010", "#f0dcc2", "#ead2b7"], "#6750a4");
        const mixedPatch = ColorUtils.getTonalPalette("#f2dfc8", ["#ffffff", "#f5e8d6", "#101010", "#050505", "#ead2b7"], "#6750a4");

        if (onLight.hslLightness > 0.2 || onDark.hslLightness < 0.85 || onOrange.hslLightness > 0.2)
            return root.fail("Tonal foreground contrast check failed");
        if (onLight.hslSaturation < 0.5 || onDark.hslSaturation < 0.5 || onMid.hslSaturation < 0.5 || onGray.hslSaturation < 0.5)
            return root.fail("Tonal foreground saturation check failed");
        if (stablePatch.foreground.hslLightness > 0.2)
            return root.fail("A single dark outlier flipped the patch foreground");
        if (!mixedPatch.haloEnabled || mixedPatch.minimumContrast >= 4.5)
            return root.fail("Mixed patch did not enable its contrast halo");
        if (mixedPatch.haloColor.r < 0.99 || mixedPatch.haloColor.g < 0.99 || mixedPatch.haloColor.b < 0.99)
            return root.fail("Contrast surface is not white");
        if (contrastFallbackText.style !== Text.Normal)
            return root.fail("Contrast fallback added a text outline or shadow");
        if (Appearance.barWorkspaceValue(1) !== 0.1 || Appearance.barWorkspaceValue(10) !== 1 || Appearance.barWorkspaceValue(11) !== 0.1)
            return root.fail("Workspace parallax normalization failed");

        console.log(`[BarColorCheck] light=${onLight} dark=${onDark} mid=${onMid} gray=${onGray} orange=${onOrange}`);
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
            if (Appearance.colors.transparentBar && !systemMonitorLoader.item.liquidGlassEnabled)
                return root.fail("Bar component did not enable liquid glass");

            console.log(`[BarColorCheck] samples=${Appearance.barSampleColumns}x${Appearance.barSampleRows} columns=${startPalette.centerColumn}->${endPalette.centerColumn}`);
            Qt.exit(0);
        }
    }
}
