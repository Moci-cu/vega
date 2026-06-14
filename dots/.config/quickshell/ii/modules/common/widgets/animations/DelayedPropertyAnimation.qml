import QtQuick
import QtQuick.Layouts

SequentialAnimation {
    id: root

    property alias target: anim.target
    property alias property: anim.property

    property int delay: 0
    property alias from: anim.from
    property alias to: anim.to
    property alias duration: anim.duration
    property alias easing: anim.easing

    PauseAnimation {
        duration: root.delay
    }

    PropertyAnimation {
        id: anim
    }
}