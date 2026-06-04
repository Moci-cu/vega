import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration

    property bool hideFront: true
    signal finished()

    function start() {
        maskContainer.layer.enabled = true
        
        let cx = effect.width / 2
        let cy = effect.height / 2
        circleMask.centerX = cx
        circleMask.centerY = cy

        // SLASH MATH: Use Manhattan Distance (|dx| + |dy|) 
        let d1 = Math.abs(cx) + Math.abs(cy)
        let d2 = Math.abs(effect.width - cx) + Math.abs(cy)
        let d3 = Math.abs(cx) + Math.abs(effect.height - cy)
        let d4 = Math.abs(effect.width - cx) + Math.abs(effect.height - cy)
        
        let maxManhattan = Math.max(d1, d2, d3, d4)

        // The exact distance from the center to the edge of a 100px wide slash is 50 * sqrt(2)
        let targetScale = maxManhattan / (50 * Math.SQRT2)

        circleMask.scale = 0 // Start invisible
        wipeMask.visible = true

        revealAnim.from = 0
        revealAnim.to = targetScale
        revealAnim.restart()
    }

    function cleanup() {
        wipeMask.visible = false
        circleMask.scale = 0
        maskContainer.layer.enabled = false
    }

    NumberAnimation {
        id: revealAnim
        target: circleMask
        property: "scale" // Animate scale, not width!
        duration: effect.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.227, 0.877, 0.959, 0.310, 1.0, 1.0]
        onFinished: effect.finished()
    }

    Item {
        id: maskContainer
        width: effect.width
        height: effect.height
        visible: false
        layer.enabled: false

        Rectangle {
            id: circleMask
            width: 100 // Fixed base width
            height: Math.ceil(Math.sqrt(effect.width * effect.width + effect.height * effect.height)) * 2
            color: "black"
            rotation: 45
            scale: 0 // Controlled by animation
            transformOrigin: Item.Center

            property real centerX: effect.width / 2
            property real centerY: effect.height / 2

            x: centerX - width / 2
            y: centerY - height / 2
        }
    }

    OpacityMask {
        id: wipeMask
        anchors.fill: parent
        visible: false
        source: effect.frontImg
        maskSource: maskContainer
    }
}
