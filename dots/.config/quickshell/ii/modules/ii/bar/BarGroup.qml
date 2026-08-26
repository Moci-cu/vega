import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: 5
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    default property alias items: gridLayout.children
    property var startRadius // left - top
    property var endRadius // right - bottom

    property color colBackground: Appearance.m3colors.m3surfaceContainerLow
    property bool liquidGlass: false
    property bool liquidGlassBackdrop: true
    property color glassColor: Qt.rgba(1, 1, 1, 0.18)
    property var wallpaperSource
    property var screen
    property real parallaxWorkspaceValue: 0.5
    property real parallaxSidebarBalance: 0

    Item {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        Rectangle {
            anchors.fill: parent
            color: root.liquidGlass ? "transparent" : root.colBackground
            topLeftRadius: root.startRadius
            bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
            topRightRadius: root.vertical ? root.startRadius : root.endRadius
            bottomRightRadius: root.endRadius

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        LiquidGlassSurface {
            anchors.fill: parent
            shown: root.liquidGlass
            backdropEnabled: root.liquidGlassBackdrop
            accountForBarPosition: true
            wallpaperSource: root.wallpaperSource
            screen: root.screen
            parallaxWorkspaceValue: root.parallaxWorkspaceValue
            parallaxSidebarBalance: root.parallaxSidebarBalance
            tintColor: root.glassColor
            radius: height / 2 // Liquid glass groups intentionally remain separate pills.
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            left: root.vertical ? undefined : parent.left
            right: root.vertical ? undefined : parent.right
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}
