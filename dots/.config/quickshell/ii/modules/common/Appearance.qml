import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions
import qs.services
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property string syntaxHighlightingTheme

    // Transparency. The quadratic functions were derived from analysis of hand-picked transparency values.
    ColorQuantizer {
        id: wallColorQuant
        property string wallpaperPath: Config.options.background.wallpaperPath
        property bool wallpaperIsVideo: wallpaperPath.endsWith(".mp4") || wallpaperPath.endsWith(".webm") || wallpaperPath.endsWith(".mkv") || wallpaperPath.endsWith(".avi") || wallpaperPath.endsWith(".mov")
        source: Qt.resolvedUrl(wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath)
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }
    property color wallpaperColor: wallColorQuant.colors[0] ?? m3colors.m3primary
    property string wallpaperSamplePath: FileUtils.trimFileProtocol(wallColorQuant.source.toString())
    readonly property int barSampleColumns: 384
    readonly property int barSampleRows: 64
    property int wallpaperSampleWidth: 1
    property int wallpaperSampleHeight: 1
    property var barBackgroundSamples: Array(barSampleColumns * barSampleRows).fill(wallpaperColor)
    property real wallpaperVibrancy: (wallColorQuant.colors[0]?.hslSaturation + wallColorQuant.colors[0]?.hslLightness) / 2

    function barWorkspaceValue(workspaceId) {
        const workspacesShown = Config.options.bar.workspaces.shown || 10;
        const id = workspaceId ?? 1;
        const workspaceLower = Math.floor((id - 1) / workspacesShown) * workspacesShown;
        return (id - workspaceLower) / workspacesShown;
    }

    function barWallpaperGeometry(screen, workspaceValue, sidebarBalance) {
        const screenWidth = screen?.width ?? 0;
        const screenHeight = screen?.height ?? 0;
        if (screenWidth <= 0 || screenHeight <= 0 || wallpaperSampleWidth <= 0 || wallpaperSampleHeight <= 0)
            return null;

        const imageToScreenRatio = Math.min(wallpaperSampleWidth / screenWidth, wallpaperSampleHeight / screenHeight);
        const wallpaperScale = wallpaperSampleWidth <= screenWidth || wallpaperSampleHeight <= screenHeight
            ? Math.max(screenWidth / wallpaperSampleWidth, screenHeight / wallpaperSampleHeight)
            : Math.min(Config.options.background.parallax.workspaceZoom, wallpaperSampleWidth / screenWidth, wallpaperSampleHeight / screenHeight);
        const displayWidth = wallpaperSampleWidth / imageToScreenRatio * wallpaperScale;
        const displayHeight = wallpaperSampleHeight / imageToScreenRatio * wallpaperScale;
        const movableXSpace = (displayWidth - screenWidth) / 2;
        const movableYSpace = (displayHeight - screenHeight) / 2;
        const verticalParallax = (Config.options.background.parallax.autoVertical && wallpaperSampleHeight > wallpaperSampleWidth)
            || Config.options.background.parallax.vertical;
        const effectiveWorkspaceValue = Config.options.background.parallax.enableWorkspace
            ? workspaceValue ?? 0.5
            : 0.5;
        const sidebarOffset = Config.options.background.parallax.enableSidebar
            ? 0.15 * sidebarBalance
            : 0;
        const effectiveValueX = Math.max(0, Math.min(1, verticalParallax ? 0.5 : effectiveWorkspaceValue)) + sidebarOffset;
        const effectiveValueY = Config.options.background.parallax.enableWorkspace && verticalParallax
            ? Math.max(0, Math.min(1, effectiveWorkspaceValue))
            : 0.5;

        return {
            screenWidth,
            screenHeight,
            displayWidth,
            displayHeight,
            wallpaperX: -movableXSpace - (effectiveValueX - 0.5) * 2 * movableXSpace,
            wallpaperY: -movableYSpace - (effectiveValueY - 0.5) * 2 * movableYSpace,
            itemScale: Config.options.overview.scrollingStyle.zoomStyle === "in" ? 1.04 : 1
        };
    }

    function barWallpaperSourceRect(x, y, width, height, screen, workspaceValue, sidebarBalance) {
        const geometry = barWallpaperGeometry(screen, workspaceValue, sidebarBalance);
        if (!geometry) return Qt.rect(0, 0, 1, 1);

        const localX = geometry.screenWidth / 2 + (x - geometry.screenWidth / 2) / geometry.itemScale;
        const localY = geometry.screenHeight / 2 + (y - geometry.screenHeight / 2) / geometry.itemScale;
        return Qt.rect(
            (localX - geometry.wallpaperX) / geometry.displayWidth,
            (localY - geometry.wallpaperY) / geometry.displayHeight,
            width / geometry.itemScale / geometry.displayWidth,
            height / geometry.itemScale / geometry.displayHeight
        );
    }

    function barPaletteAt(x, sampleWidth, screen, workspaceValue, sidebarBalance) {
        if (LyricsService.mediaModeOpenCount > 0) {
            return {
                foreground: "#FFFFFF",
                haloEnabled: false,
                haloColor: "transparent",
                minimumContrast: 21,
                sampleCount: 0,
                centerColumn: -1
            };
        }

        const geometry = barWallpaperGeometry(screen, workspaceValue, sidebarBalance);
        if (!geometry || barBackgroundSamples.length === 0) {
            const fallback = ColorUtils.getTonalPalette(wallpaperColor, [wallpaperColor], m3colors.m3primary);
            fallback.sampleCount = 1;
            fallback.centerColumn = -1;
            return fallback;
        }

        const localX = geometry.screenWidth / 2 + (x - geometry.screenWidth / 2) / geometry.itemScale;
        const barCenterY = Config.options.bar.bottom
            ? geometry.screenHeight - root.sizes.barHeight / 2
            : root.sizes.barHeight / 2;
        const localY = geometry.screenHeight / 2 + (barCenterY - geometry.screenHeight / 2) / geometry.itemScale;
        const centerSourceX = Math.max(0, Math.min(1, (localX - geometry.wallpaperX) / geometry.displayWidth));
        const centerColumn = Math.min(barSampleColumns - 1, Math.floor(centerSourceX * barSampleColumns));
        const sourceY = Math.max(0, Math.min(1, (localY - geometry.wallpaperY) / geometry.displayHeight));
        const row = Math.min(barSampleRows - 1, Math.floor(sourceY * barSampleRows));
        const patchWidth = Math.max(16, Math.min(64, Number(sampleWidth) || 16));
        const offsets = [-0.5, -0.25, 0, 0.25, 0.5];
        const samples = offsets.map(offset => {
            const sourceX = Math.max(0, Math.min(1, (localX + offset * patchWidth / geometry.itemScale - geometry.wallpaperX) / geometry.displayWidth));
            const column = Math.min(barSampleColumns - 1, Math.floor(sourceX * barSampleColumns));
            return barBackgroundSamples[row * barSampleColumns + column] ?? wallpaperColor;
        });
        const palette = ColorUtils.getTonalPalette(samples[2], samples, m3colors.m3primary);
        palette.sampleCount = samples.length;
        palette.centerColumn = centerColumn;
        return palette;
    }

    function barForegroundAt(x, screen, workspaceId, sidebarBalance, sampleWidth = 16) {
        return barPaletteAt(x, sampleWidth, screen, barWorkspaceValue(workspaceId), sidebarBalance).foreground;
    }

    onWallpaperSamplePathChanged: barColorSampleTimer.restart()
    Component.onCompleted: barColorSampleTimer.restart()

    Timer {
        id: barColorSampleTimer
        interval: 50
        onTriggered: {
            barColorSampler.running = false;
            if (root.wallpaperSamplePath !== "") barColorSampler.running = true;
        }
    }

    Process {
        id: barColorSampler
        command: [
            "magick", root.wallpaperSamplePath,
            "-print", "%w %h\n",
            "-resize", `${root.barSampleColumns}x${root.barSampleRows}!`, "-depth", "8", "txt:-"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                const dimensions = text.match(/^(\d+)\s+(\d+)/);
                const samples = text.match(/#[0-9A-Fa-f]{6}/g);
                if (!dimensions || !samples || samples.length !== root.barSampleColumns * root.barSampleRows) return;
                root.wallpaperSampleWidth = Number(dimensions[1]);
                root.wallpaperSampleHeight = Number(dimensions[2]);
                root.barBackgroundSamples = samples;
            }
        }
    }
    property real autoBackgroundTransparency: { // y = 0.5768x^2 - 0.759x + 0.2896
        let x = wallpaperVibrancy
        let y = 0.5768 * (x * x) - 0.759 * (x) + 0.2896
        return Math.max(0, Math.min(0.22, y)) - 0.12 * (m3colors.darkmode ? 0 : 1)
    }
    property real autoContentTransparency: 0.9
    property real backgroundTransparency: Config?.options.appearance.transparency.enable ? Config?.options.appearance.transparency.automatic ? autoBackgroundTransparency : Config?.options.appearance.transparency.backgroundTransparency : 0
    property real contentTransparency: Config?.options.appearance.transparency.automatic ? autoContentTransparency : Config?.options.appearance.transparency.contentTransparency
    property real functionalSurfaceTransparency: Config?.options.appearance.transparency.enable
        ? (Config?.options.appearance.transparency.automatic ? 0.26 : backgroundTransparency)
        : 0

    m3colors: QtObject {
        property bool darkmode: true
        property bool transparent: false
        property color m3background: "#141313"
        property color m3onBackground: "#e6e1e1"
        property color m3surface: "#141313"
        property color m3surfaceDim: "#141313"
        property color m3surfaceBright: "#3a3939"
        property color m3surfaceContainerLowest: "#0f0e0e"
        property color m3surfaceContainerLow: "#1c1b1c"
        property color m3surfaceContainer: "#201f20"
        property color m3surfaceContainerHigh: "#2b2a2a"
        property color m3surfaceContainerHighest: "#363435"
        property color m3onSurface: "#e6e1e1"
        property color m3surfaceVariant: "#49464a"
        property color m3onSurfaceVariant: "#cbc5ca"
        property color m3inverseSurface: "#e6e1e1"
        property color m3inverseOnSurface: "#313030"
        property color m3outline: "#948f94"
        property color m3outlineVariant: "#49464a"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#cbc4cb"
        property color m3primary: "#cbc4cb"
        property color m3onPrimary: "#322f34"
        property color m3primaryContainer: "#2d2a2f"
        property color m3onPrimaryContainer: "#bcb6bc"
        property color m3inversePrimary: "#615d63"
        property color m3secondary: "#cac5c8"
        property color m3onSecondary: "#323032"
        property color m3secondaryContainer: "#4d4b4d"
        property color m3onSecondaryContainer: "#ece6e9"
        property color m3tertiary: "#d1c3c6"
        property color m3onTertiary: "#372e30"
        property color m3tertiaryContainer: "#31292b"
        property color m3onTertiaryContainer: "#c1b4b7"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3primaryFixed: "#e7e0e7"
        property color m3primaryFixedDim: "#cbc4cb"
        property color m3onPrimaryFixed: "#1d1b1f"
        property color m3onPrimaryFixedVariant: "#49454b"
        property color m3secondaryFixed: "#e6e1e4"
        property color m3secondaryFixedDim: "#cac5c8"
        property color m3onSecondaryFixed: "#1d1b1d"
        property color m3onSecondaryFixedVariant: "#484648"
        property color m3tertiaryFixed: "#eddfe1"
        property color m3tertiaryFixedDim: "#d1c3c6"
        property color m3onTertiaryFixed: "#211a1c"
        property color m3onTertiaryFixedVariant: "#4e4447"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color term0: "#EDE4E4"
        property color term1: "#B52755"
        property color term2: "#A97363"
        property color term3: "#AF535D"
        property color term4: "#A67F7C"
        property color term5: "#B2416B"
        property color term6: "#8D76AD"
        property color term7: "#272022"
        property color term8: "#0E0D0D"
        property color term9: "#B52755"
        property color term10: "#A97363"
        property color term11: "#AF535D"
        property color term12: "#A67F7C"
        property color term13: "#B2416B"
        property color term14: "#8D76AD"
        property color term15: "#221A1A"
    }

    colors: QtObject {
        property color colSubtext: m3colors.m3outline
        // Layer 0
        property color colLayer0Base: ColorUtils.mix(m3colors.m3background, m3colors.m3primary, Config.options.appearance.extraBackgroundTint ? 0.99 : 1)
        property color colLayer0: ColorUtils.transparentize(colLayer0Base, root.backgroundTransparency)
        property color colGlassSurface: ColorUtils.transparentize(colLayer0Base, root.functionalSurfaceTransparency)
        property color colGlassSurfaceContainer: ColorUtils.transparentize(m3colors.m3surfaceContainer, root.functionalSurfaceTransparency)
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.9, root.contentTransparency))
        property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.8, root.contentTransparency))
        property color colLayer0Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        // Layer 1
        property color colLayer1Base: m3colors.m3surfaceContainerLow
        property color colLayer1: ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency);
        property color colOnLayer1: m3colors.m3onSurfaceVariant;
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45);
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency);
        // Layer 2
        property color colLayer2Base: m3colors.m3surfaceContainer
        property color colLayer2: ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency);
        property color colLayer2Disabled: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency);
        property color colOnLayer2: m3colors.m3onSurface;
        property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4);
        // Layer 3
        property color colLayer3Base: m3colors.m3surfaceContainerHigh
        property color colLayer3: ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency);
        property color colOnLayer3: m3colors.m3onSurface;
        // Layer 4
        property color colLayer4Base: m3colors.m3surfaceContainerHighest
        property color colLayer4: ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency);
        property color colOnLayer4: m3colors.m3onSurface;
        // Primary
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryHover: ColorUtils.mix(colors.colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: ColorUtils.mix(colors.colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.8)
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        // Secondary
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryHover: ColorUtils.mix(m3colors.m3secondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: ColorUtils.mix(m3colors.m3secondary, colLayer1Active, 0.4)
        property color colOnSecondary: m3colors.m3onSecondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.54)
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        // Tertiary
        property color colTertiary: m3colors.m3tertiary
        property color colTertiaryHover: ColorUtils.mix(m3colors.m3tertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: ColorUtils.mix(m3colors.m3tertiary, colLayer1Active, 0.4)
        property color colTertiaryContainer: m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: ColorUtils.mix(m3colors.m3tertiaryContainer, m3colors.m3onTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: ColorUtils.mix(m3colors.m3tertiaryContainer, colLayer1Active, 0.54)
        property color colOnTertiary: m3colors.m3onTertiary
        property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer
        // Surface
        property color colBackgroundSurfaceContainer: ColorUtils.transparentize(m3colors.m3surfaceContainer, root.backgroundTransparency)
        property color colSurfaceContainerLow: ColorUtils.solveOverlayColor(m3colors.m3background, m3colors.m3surfaceContainerLow, 1 - root.contentTransparency)
        property color colSurfaceContainer: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerLow, m3colors.m3surfaceContainer, 1 - root.contentTransparency)
        property color colSurfaceContainerHigh: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainer, m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency)
        property color colSurfaceContainerHighest: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerHigh, m3colors.m3surfaceContainerHighest, 1 - root.contentTransparency)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.85)
        property color colOnSurface: m3colors.m3onSurface
        property color colOnSurfaceVariant: m3colors.m3onSurfaceVariant
        property bool transparentBar: Config.options.bar.barGroupStyle === 2 && Config.options.bar.barBackgroundStyle === 0
        // Misc
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
        property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: m3colors.m3outline
        property color colOutlineVariant: m3colors.m3outlineVariant
        property color colError: m3colors.m3error
        property color colErrorHover: ColorUtils.mix(m3colors.m3error, colLayer1Hover, 0.85)
        property color colErrorActive: ColorUtils.mix(m3colors.m3error, colLayer1Active, 0.7)
        property color colOnError: m3colors.m3onError
        property color colErrorContainer: m3colors.m3errorContainer
        property color colErrorContainerHover: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.90)
        property color colErrorContainerActive: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.70)
        property color colOnErrorContainer: m3colors.m3onErrorContainer
    }

    rounding: QtObject {
        property int unsharpen: Config.options.appearance.sharpMode ? 0 : 2
        property int unsharpenmore: Config.options.appearance.sharpMode ? 0 : 6
        property int verysmall: Config.options.appearance.sharpMode ? 0 : 8
        property int small: Config.options.appearance.sharpMode ? 0 : 12
        property int normal: Config.options.appearance.sharpMode ? 0 : 17
        property int large: Config.options.appearance.sharpMode ? 0 : 23
        property int verylarge: Config.options.appearance.sharpMode ? 0 : 30
        property int full: Config.options.appearance.sharpMode ? 0 : 9999
        property int screenRounding: large
        property int windowRounding: Config.options.appearance.sharpMode ? 0 : 18
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: Config.options.appearance.fonts.main
            property string numbers: Config.options.appearance.fonts.numbers
            property string title: Config.options.appearance.fonts.title
            property string iconMaterial: "Material Symbols Rounded"
            property string iconNerd: Config.options.appearance.fonts.iconNerd
            property string monospace: Config.options.appearance.fonts.monospace
            property string reading: Config.options.appearance.fonts.reading
            property string expressive: Config.options.appearance.fonts.expressive
        }
        property QtObject variableAxes: QtObject {
            property var main: ({
                "wght": 450,
                "wdth": 100,
            })
            property var numbers: ({
                "wght": 450,
            })
            property var title: ({ // Slightly bold weight for title
                "wght": 550, // Weight (Lowered to compensate for increased grade)
            })
        }
        property QtObject pixelSize: QtObject {
            property int smallest: 10
            property int smaller: 12
            property int smallie: 13
            property int small: 15
            property int normal: 16
            property int large: 17
            property int larger: 19
            property int huge: 22
            property int hugeass: 23
            property int title: huge
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // Default, 350ms
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // Default, 500ms
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // Default, 650ms
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // Default, 200ms
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveSmall: QtObject {
            property int duration: animationCurves.expressiveFastSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSmall.duration
                    easing.type: root.animation.elementMoveSmall.type
                    easing.bezierCurve: root.animation.elementMoveSmall.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveExit: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }

        property QtObject elementMoveSlow: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration * 2.5
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveSlow.duration
                easing.type: root.animation.elementMoveSlow.type
                easing.bezierCurve: root.animation.elementMoveSlow.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.elementMoveSlow.duration
                easing.type: root.animation.elementMoveSlow.type
                easing.bezierCurve: root.animation.elementMoveSlow.bezierCurve
            }}
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
        }

        property QtObject elementResize: QtObject {
            property int duration: 300
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasized
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementResize.duration
                    easing.type: root.animation.elementResize.type
                    easing.bezierCurve: root.animation.elementResize.bezierCurve
                }
            }
        }

        property QtObject clickBounce: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 850
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.clickBounce.duration
                easing.type: root.animation.clickBounce.type
                easing.bezierCurve: root.animation.clickBounce.bezierCurve
            }}
        }
        
        property QtObject scroll: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: root.animationCurves.standardDecel
        }

        property QtObject menuDecel: QtObject {
            property int duration: 350
            property int type: Easing.OutExpo
        }
    }

    sizes: QtObject {
        property real baseBarHeight: Config.options.bar.sizes.height
        property real barHeight: Config.options.bar.cornerStyle === 1 ? 
            (baseBarHeight + root.sizes.hyprlandGapsOut * 2) : baseBarHeight
        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real elevationMargin: 10
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real mediaControlsWidth: 440
        property real mediaControlsHeight: 160
        property real notificationPopupWidth: 410
        property real osdWidth: 200
        property real searchWidthCollapsed: 210
        property real searchWidth: 360
        property real sidebarWidth: 460
        property real sidebarWidthExpanded: 570 // when all 4 policies are enabled
        property real sidebarWidthExtended: 750
        property real baseVerticalBarWidth: Config.options.bar.sizes.width
        property real verticalBarWidth: Config.options.bar.cornerStyle === 1 ? 
            (baseVerticalBarWidth + root.sizes.hyprlandGapsOut * 2) : baseVerticalBarWidth
        property real wallpaperSelectorWidth: 1200
        property real wallpaperSelectorHeight: 690
        property real wallpaperSelectorItemMargins: 8
        property real wallpaperSelectorItemPadding: 6
        property int dockButtonSize: Math.round((Config.options?.dock.height ?? 60) * 0.85)
    }

    syntaxHighlightingTheme: root.m3colors.darkmode ? "Monokai" : "ayu Light"
}
