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
        
        let marginX = effect.width * 0.25
        let marginY = effect.height * 0.25
        let cx = marginX + Math.random() * (effect.width - marginX * 2)
        let cy = marginY + Math.random() * (effect.height - marginY * 2)
        circleMask.centerX = cx
        circleMask.centerY = cy

        let d1 = Math.sqrt(cx * cx + cy * cy)
        let d2 = Math.sqrt((effect.width - cx) * (effect.width - cx) + cy * cy)
        let d3 = Math.sqrt(cx * cx + (effect.height - cy) * (effect.height - cy))
        let d4 = Math.sqrt((effect.width - cx) * (effect.width - cx) + (effect.height - cy) * (effect.height - cy))
        let targetDiameter = Math.ceil(Math.max(d1, d2, d3, d4)) * 2

        // Divide target by our fixed base width (100)
        let targetScale = targetDiameter / 100

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
        easing.type: Easing.OutCubic
        onFinished: effect.finished()
    }

    Item {
        id: maskContainer
        width: effect.width
        height: effect.height
        visible: false
        layer.enabled: false

        Item {
            id: pivot
            x: circleMask.centerX
            y: circleMask.centerY
            width: 1
            height: 1

            Rectangle {
                id: circleMask
                anchors.centerIn: parent
                width: 100 // Fixed base width
                height: Math.ceil(Math.sqrt(effect.width * effect.width + effect.height * effect.height)) * 2
                color: "black"
                rotation: 45
                scale: 0 // Controlled by animation
                transformOrigin: Item.Center

                property real centerX: effect.width / 2
                property real centerY: effect.height / 2
            }
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
