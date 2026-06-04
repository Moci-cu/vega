import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration

    property bool hideFront: true
    signal finished()

    function start() {
        maskContainer.layer.enabled = true
        wipeRect.width = 0
        wipeMask.visible = true
        
        revealAnim.from = 0
        revealAnim.to = pivot.diagonal + 150
        revealAnim.restart()
    }

    function cleanup() {
        wipeMask.visible = false
        wipeRect.width = 0
        maskContainer.layer.enabled = false
    }

    NumberAnimation {
        id: revealAnim
        target: wipeRect
        property: "width"
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

        Item {
            id: pivot
            x: effect.width / 2
            y: effect.height / 2
            rotation: Config.options.background.wipeAngle ?? 0
            
            property real diagonal: Math.ceil(Math.sqrt(effect.width * effect.width + effect.height * effect.height))

            Rectangle {
                id: wipeRect
                color: "black"
                height: pivot.diagonal
                y: -pivot.diagonal / 2
                x: -pivot.diagonal / 2
                width: 0
            }

            Image {
                id: waveImage
                source: "data:image/svg+xml;utf8,<svg width='100' height='400' xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='none'><path d='M0,0 L50,0 Q100,25 50,50 T50,100 Q100,125 50,150 T50,200 Q100,225 50,250 T50,300 Q100,325 50,350 T50,400 L0,400 Z' fill='black'/></svg>"
                x: wipeRect.x + wipeRect.width - 1
                y: -pivot.diagonal / 2
                width: 150
                height: pivot.diagonal
                fillMode: Image.Stretch
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
