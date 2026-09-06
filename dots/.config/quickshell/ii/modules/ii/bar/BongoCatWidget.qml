import QtQuick
import Quickshell
import qs.modules.common
import qs.services

Item {
    id: root
    property bool vertical: false
    property bool tracking: false
    readonly property var frames: ["both-up", "left-down", "right-down", "both-down"]
    implicitHeight: vertical ? implicitWidth * 220 / 365 : (Appearance.sizes.baseBarHeight - 4) * 1.2
    implicitWidth: vertical ? (Appearance.sizes.baseVerticalBarWidth - 10) * 1.2 : implicitHeight * 365 / 220
    Accessible.role: Accessible.Graphic
    Accessible.name: "Bongo Cat"
    Accessible.description: BongoCat.available ? "Reacts to keyboard activity" : "Keyboard input unavailable"

    function updateTracking() {
        if (tracking === visible) return;
        tracking = visible;
        BongoCat.activeInstances += tracking ? 1 : -1;
    }
    Component.onCompleted: updateTracking()
    onVisibleChanged: updateTracking()
    Component.onDestruction: {
        if (tracking) BongoCat.activeInstances--;
    }

    // Preload all transparent frames so taps only switch visibility.
    Repeater {
        model: root.frames
        Image {
            required property string modelData
            required property int index
            anchors.fill: parent
            source: Quickshell.shellPath("assets/bongocat/bongo-" + modelData + ".svg")
            sourceSize.width: Math.ceil(root.width * 2)
            sourceSize.height: Math.ceil(root.height * 2)
            fillMode: Image.PreserveAspectFit
            visible: BongoCat.paws === index
        }
    }
}
