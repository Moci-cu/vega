import qs.modules.common
import QtQuick
import Quickshell

Item {
    id: root

    property bool shown: false
    property bool backdropEnabled: true
    property var wallpaperSource
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
    readonly property real screenY: scenePosition.y + (Config.options.bar.bottom
        ? Math.max(0, (screen?.height ?? 0) - (root.QsWindow.window?.height ?? 0))
        : 0)
    readonly property rect wallpaperRect: Appearance.barWallpaperSourceRect(
        scenePosition.x,
        screenY,
        width,
        height,
        screen,
        parallaxWorkspaceValue,
        parallaxSidebarBalance
    )
    readonly property bool shaderReady: backdropEnabled
        && !!wallpaperSource
        && wallpaperSource.status === Image.Ready
        && width > 0
        && height > 0

    opacity: shown ? 1 : 0
    visible: opacity > 0
    clip: true

    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.52)
        opacity: root.shaderReady ? 0 : 1
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b, Math.min(0.32, root.tintColor.a + 0.1))
            }
            GradientStop {
                position: 0.48
                color: root.tintColor
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b, Math.max(0.08, root.tintColor.a - 0.06))
            }
        }

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: root.shaderReady ? 1 : 0

        property var source: root.wallpaperSource
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d sourceRect: Qt.vector4d(
            root.wallpaperRect.x,
            root.wallpaperRect.y,
            root.wallpaperRect.width,
            root.wallpaperRect.height
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
        property vector2d lightDirection: Qt.vector2d(Math.cos(lightAngle), Math.sin(lightAngle))
        property real refraction: 5

        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
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
        color: Qt.rgba(1, 1, 1, 0.3)
        opacity: root.shaderReady ? 0 : 1

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }
}
