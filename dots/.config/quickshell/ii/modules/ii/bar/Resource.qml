import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property color fallbackForegroundColor: Appearance.colors.colOnLayer1
    property var screen
    property real parallaxWorkspaceValue: 0.5
    property real parallaxSidebarBalance: 0
    readonly property real screenCenterX: {
        width;
        x;
        let ancestor = parent;
        while (ancestor) {
            ancestor.x;
            ancestor.width;
            ancestor = ancestor.parent;
        }
        return mapToItem(null, width / 2, 0).x;
    }
    readonly property var adaptivePalette: Appearance.colors.transparentBar
        ? Appearance.barPaletteAt(screenCenterX, width, screen, parallaxWorkspaceValue, parallaxSidebarBalance)
        : ({ foreground: fallbackForegroundColor })
    property color foregroundColor: Appearance.colors.transparentBar ? adaptivePalette.foreground : fallbackForegroundColor
    required property string iconName
    required property double percentage
    property string valueText: `${Math.round(percentage * 100).toString()}`
    property int warningThreshold: 100
    property bool shown: true
    clip: true
    visible: width > 0 && height > 0
    implicitWidth: resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight
    property bool warning: percentage * 100 >= warningThreshold

    RowLayout {
        id: resourceRowLayout
        spacing: 2
        x: shown ? 0 : -resourceRowLayout.width
        anchors {
            verticalCenter: parent.verticalCenter
        }

        ClippedFilledCircularProgress {
            id: resourceCircProg
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: percentage
            implicitSize: 20
            colPrimary: root.warning ? Appearance.colors.colError : root.foregroundColor
            accountForLightBleeding: !root.warning
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: resourceCircProg.implicitSize
                height: resourceCircProg.implicitSize
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.foregroundColor
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: fullPercentageTextMetrics.width
            implicitHeight: percentageText.implicitHeight

            TextMetrics {
                id: fullPercentageTextMetrics
                text: root.valueText.includes("°") ? "100°" : "100"
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                id: percentageText
                anchors.centerIn: parent
                color: root.foregroundColor
                font.pixelSize: Appearance.font.pixelSize.small
                text: root.valueText
            }
        }

        Behavior on x {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: resourceRowLayout.x >= 0 && root.width > 0 && root.visible
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }
}
