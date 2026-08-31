import qs.modules.common
import QtQuick
import Quickshell

Item {
    id: root

    property bool shown: false
    property bool backdropEnabled: true
    property bool compositorBackdrop: false
    property bool accountForBarPosition: false
    property bool sourceFillsItem: false
    property bool enhancedOptics: false
    property bool interactiveOptics: false
    property bool responsiveOptics: false
    property real interaction: 0
    property point interactionPoint: Qt.point(0.5, 0.5)
    property real thicknessOverride: -1
    property real edgeLighting: 1
    property real lowerGlow: 0
    property real ambientSpillStrength: -1
    property real ambientDiffusion: 0
    property bool detailedEnvironment: false
    property real refraction: 5
    property rect itemSourceRect: Qt.rect(0, 0, 1, 1)
    property var wallpaperSource
    property var environmentSource
    property bool sourceReady: wallpaperSource?.status === Image.Ready
    property var screen
    property real parallaxWorkspaceValue: 0.5
    property real parallaxSidebarBalance: 0
    property color tintColor: Qt.rgba(1, 1, 1, 0.18)
    property real radius: Appearance.rounding.full
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    readonly property point scenePosition: {
        root.x;
        root.y;
        root.width;
        root.height;
        let ancestor = root.parent;
        while (ancestor) {
            ancestor.x;
            ancestor.y;
            ancestor.width;
            ancestor.height;
            ancestor = ancestor.parent;
        }
        return root.mapToItem(null, 0, 0);
    }
    readonly property real screenY: scenePosition.y + (root.accountForBarPosition && Config.options.bar.bottom
        ? Math.max(0, (screen?.height ?? 0) - (root.QsWindow.window?.height ?? 0))
        : 0)
    readonly property rect sampleRect: sourceFillsItem
        ? itemSourceRect
        : Appearance.barWallpaperSourceRect(
            scenePosition.x,
            screenY,
            width,
            height,
            screen,
            parallaxWorkspaceValue,
            parallaxSidebarBalance
        )
    readonly property bool textureShaderReady: !compositorBackdrop
        && backdropEnabled
        && !!wallpaperSource
        && sourceReady
        && width > 0
        && height > 0
    readonly property bool compositorRimReady: compositorBackdrop
        && backdropEnabled
        && !!wallpaperSource
        && sourceReady
        && width > 0
        && height > 0
    readonly property bool shaderReady: textureShaderReady || compositorRimReady

    opacity: shown ? 1 : 0
    visible: opacity > 0
    clip: true

    Behavior on opacity {
        enabled: !root.compositorBackdrop
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.52 * root.edgeLighting)
        opacity: !root.compositorBackdrop && !root.textureShaderReady ? 1 : 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b,
                    root.lowerGlow > 0 ? Math.min(0.82, root.tintColor.a + 0.12) : Math.min(0.32, root.tintColor.a + 0.1))
            }
            GradientStop {
                position: root.lowerGlow > 0 ? 0.68 : 0.48
                color: root.tintColor
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b,
                    root.lowerGlow > 0 ? Math.max(0.08, root.tintColor.a * 0.72) : Math.max(0.08, root.tintColor.a - 0.06))
            }
        }

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        antialiasing: true
        opacity: root.compositorBackdrop ? 1 : 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b,
                    Math.min(0.9, root.tintColor.a + 0.20 * root.lowerGlow))
            }
            GradientStop {
                position: 0.38
                color: root.tintColor
            }
            GradientStop {
                position: 0.72
                color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b,
                    Math.max(0.26, root.tintColor.a * (1 - 0.42 * root.lowerGlow)))
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b,
                    Math.max(0.24, root.tintColor.a * (1 - 0.66 * root.lowerGlow)))
            }
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.textureShaderReady ? 1 : 0

        property var source: root.wallpaperSource
        property var environmentSource: root.environmentSource ?? root.wallpaperSource
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d sourceRect: Qt.vector4d(
            root.sampleRect.x,
            root.sampleRect.y,
            root.sampleRect.width,
            root.sampleRect.height
        )
        property vector4d cornerRadii: Qt.vector4d(
            root.topLeftRadius,
            root.topRightRadius,
            root.bottomRightRadius,
            root.bottomLeftRadius
        )
        property color glassTint: root.tintColor
        property real lightAngle: -0.82
            + 0.28 * ((root.scenePosition.x + root.width / 2) / Math.max(1, root.screen?.width ?? 1) - 0.5)
            + 0.22 * (root.parallaxWorkspaceValue - 0.5)
            + 0.08 * root.parallaxSidebarBalance
            + 0.45 * root.interaction * (root.interactionPoint.x - 0.5)
        property vector2d lightDirection: Qt.vector2d(Math.cos(lightAngle), Math.sin(lightAngle))
        property real refraction: root.refraction
        property real enhancedOptics: root.enhancedOptics ? 1 : 0
        property real interactiveOptics: root.interactiveOptics ? 1 : 0
        property real responsiveOptics: root.responsiveOptics ? 1 : 0
        property real interaction: root.interaction
        property vector2d interactionPoint: Qt.vector2d(root.interactionPoint.x, root.interactionPoint.y)
        property real thicknessOverride: root.thicknessOverride
        property real edgeLighting: root.edgeLighting
        property real lowerGlow: root.lowerGlow
        property real ambientSpillStrength: root.ambientSpillStrength
        property real ambientDiffusion: root.ambientDiffusion
        property bool detailedEnvironment: root.detailedEnvironment

        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb?rev=apple-fresnel-22")

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.compositorRimReady ? 1 : 0

        property var source: root.wallpaperSource
        property var environmentSource: root.environmentSource ?? root.wallpaperSource
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d sourceRect: Qt.vector4d(
            root.sampleRect.x,
            root.sampleRect.y,
            root.sampleRect.width,
            root.sampleRect.height
        )
        property vector4d cornerRadii: Qt.vector4d(
            root.topLeftRadius,
            root.topRightRadius,
            root.bottomRightRadius,
            root.bottomLeftRadius
        )
        property real edgeLighting: root.edgeLighting
        property real lowerGlow: root.lowerGlow

        fragmentShader: Qt.resolvedUrl("shaders/liquidglassrim.frag.qsb?rev=optical-overlay-17")
    }

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 1
            leftMargin: Math.min(parent.width / 3, root.topLeftRadius, parent.height / 2) + 1
            rightMargin: Math.min(parent.width / 3, root.topRightRadius, parent.height / 2) + 1
        }
        height: 1
        radius: 0.5
        color: Qt.rgba(1, 1, 1, 0.3 * root.edgeLighting)
        opacity: !root.compositorBackdrop && !root.textureShaderReady ? 1 : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }
}
