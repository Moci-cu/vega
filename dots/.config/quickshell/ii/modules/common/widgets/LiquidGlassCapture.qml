import QtQuick
import QtQuick.Effects
import Quickshell.Wayland

Item {
    id: root

    required property var screen
    required property Item target
    property bool active: false
    property real padding: 48
    property real windowOriginX: 0
    property real windowOriginY: 0

    readonly property point targetScenePosition: {
        if (!root.target)
            return Qt.point(0, 0);
        root.target.x;
        root.target.y;
        root.target.width;
        root.target.height;
        let ancestor = root.target.parent;
        while (ancestor) {
            ancestor.x;
            ancestor.y;
            ancestor.width;
            ancestor.height;
            ancestor = ancestor.parent;
        }
        return root.target.mapToItem(null, 0, 0);
    }
    readonly property real targetScreenX: root.windowOriginX + root.targetScenePosition.x
    readonly property real targetScreenY: root.windowOriginY + root.targetScenePosition.y
    readonly property real cropX: Math.max(0, root.targetScreenX - root.padding)
    readonly property real cropY: Math.max(0, root.targetScreenY - root.padding)
    readonly property real cropRight: Math.min(root.screen?.width ?? 1, root.targetScreenX + root.target.width + root.padding)
    readonly property real cropBottom: Math.min(root.screen?.height ?? 1, root.targetScreenY + root.target.height + root.padding)
    readonly property real targetOffsetX: root.targetScreenX - root.cropX
    readonly property real targetOffsetY: root.targetScreenY - root.cropY
    readonly property real sourceWidth: backdrop.width
    readonly property real sourceHeight: backdrop.height
    readonly property var source: backdrop
    readonly property bool ready: capture.hasContent

    width: 1
    height: 1

    ScreencopyView {
        id: capture
        width: Math.max(1, root.screen?.width ?? 1)
        height: Math.max(1, root.screen?.height ?? 1)
        captureSource: root.active ? root.screen : null
        live: false
        paintCursor: false
    }

    ShaderEffectSource {
        id: crop
        visible: false
        width: Math.max(1, root.cropRight - root.cropX)
        height: Math.max(1, root.cropBottom - root.cropY)
        sourceItem: capture
        sourceRect: Qt.rect(root.cropX, root.cropY, width, height)
        textureSize: Qt.size(
            Math.ceil(width * (root.screen?.devicePixelRatio ?? 1)),
            Math.ceil(height * (root.screen?.devicePixelRatio ?? 1))
        )
        hideSource: true
        live: root.active && capture.hasContent
    }

    MultiEffect {
        id: blur
        width: crop.width
        height: crop.height
        source: crop
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 40
        blur: 1
    }

    ShaderEffectSource {
        id: backdrop
        visible: false
        width: blur.width
        height: blur.height
        sourceItem: blur
        sourceRect: Qt.rect(0, 0, width, height)
        textureSize: Qt.size(
            Math.ceil(width * (root.screen?.devicePixelRatio ?? 1)),
            Math.ceil(height * (root.screen?.devicePixelRatio ?? 1))
        )
        hideSource: true
        live: root.active && capture.hasContent
    }
}
