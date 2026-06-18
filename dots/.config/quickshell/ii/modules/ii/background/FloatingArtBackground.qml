import QtQuick
import QtQuick.Effects
import qs
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property real animationSpeedScale
    required property string artFilePath
    required property color overlayColor
    required property bool animationEnabled

    // Parallax - sidebar
    property real parallaxStrength: 30
    // Parallax - workspace
    required property real workspaceNorm
    property real workspaceParallaxStrength: 40
    readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical

    property real parallaxX: {
        const sidebar = (GlobalStates.effectiveRightOpen - GlobalStates.effectiveLeftOpen) * parallaxStrength
        const ws = verticalParallax ? 0 : (workspaceNorm - 0.5) * -2 * workspaceParallaxStrength
        return sidebar + ws
    }
    property real parallaxY: {
        return verticalParallax ? (workspaceNorm - 0.5) * -2 * workspaceParallaxStrength : 0
    }
    
    // using normal animations feels too flat
    Behavior on parallaxX {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }
    Behavior on parallaxY {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    // ponytail: GaussianBlur removed — was causing 20W CPU / 80°C. Add back when GPU budget allows.

    TransitionImage {
        id: img
        anchors.fill: parent
        imageSource: root.artFilePath
        visible: false

        Rectangle { anchors.fill: parent; color: root.overlayColor }

        transform: [
            Scale {
                origin.x: img.width / 2; origin.y: img.height / 2
                xScale: 1.15; yScale: 1.15
            },
            Translate { id: floatTranslate },
            Translate { id: parallaxTranslate; x: -root.parallaxX; y: root.parallaxY }
        ]

        // ponytail: AxisAnimation removed — continuous render was causing lag. Add back when animation budget allows.
    }
}