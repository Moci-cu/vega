import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets.animations

TriggerAnimation {
    id: root 

    property Item targetPlaceholder
    property bool rotateToRight: true

    animation: SequentialAnimation {
        ParallelAnimation {
            // reseting text values to where they should be
            PropertyAction { targets: [targetPlaceholder.titleWidget, targetPlaceholder.descriptionWidget]; property: "opacity"; value: 0 }
            PropertyAction { targets: [targetPlaceholder.titleWidget, targetPlaceholder.descriptionWidget]; property: "Layout.topMargin"; value: -40 }

            // rotating the icon widget right/left
            PropertyAnimation {
                target: targetPlaceholder.iconWidget; property: "rotation"
                from: rotateToRight ? -50 : 50; to: 0; duration: 250
                easing.type: Easing.OutCubic
            }

            // scaling the icon widget
            BounceAnimation {
                target: targetPlaceholder.iconWidget
                propertyName: "scale"
                peak: 1.1
                totalDuration: 400
            }
        }

        // sliding the texts under the icon
        ParallelAnimation {
            FadeSlide { target: targetPlaceholder.titleWidget }
            FadeSlide { target: targetPlaceholder.descriptionWidget; delay: 50 }
        }
    }

    component FadeSlide: ParallelAnimation {
        id: animRoot
        property var target
        property int delay: 0
        property real fromY: -40
        property int duration: 350

        PropertyAnimation { 
            target: animRoot.target; property: "opacity"; from: 0; to: 1
            duration: animRoot.duration - 50; easing.type: Easing.OutCubic 
        }
        DelayedPropertyAnimation {
            target: animRoot.target; property: "Layout.topMargin"; from: animRoot.fromY; to: 0
            duration: animRoot.duration; easing.type: Easing.OutCubic; delay: animRoot.delay
        }
    }
}