import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    required property string name
    property var shape
    property bool showProgressBar: true
    property bool rotateIcon: false
    property bool scaleIcon: false
    property var glassCapture
    property alias from: valueProgressBar.from
    property alias to: valueProgressBar.to

    property real valueIndicatorVerticalPadding: 9
    property real valueIndicatorLeftPadding: 15
    property real valueIndicatorRightPadding: 15 // An icon is circle ish, a column isn't, hence the extra padding

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    Item {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        property real radius: Appearance.rounding.full

        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        LiquidGlassSurface {
            id: glassSurface
            anchors.fill: parent
            readonly property point targetPosition: {
                valueIndicator.x;
                valueIndicator.y;
                root.x;
                root.y;
                return root.glassCapture?.target
                    ? valueIndicator.mapToItem(root.glassCapture.target, 0, 0)
                    : Qt.point(0, 0);
            }

            shown: true
            wallpaperSource: root.glassCapture?.source ?? null
            sourceReady: root.glassCapture?.ready ?? false
            sourceFillsItem: true
            enhancedOptics: true
            thicknessOverride: 0.15
            itemSourceRect: Qt.rect(
                ((root.glassCapture?.targetOffsetX ?? 0) + targetPosition.x) / Math.max(1, root.glassCapture?.sourceWidth ?? 1),
                ((root.glassCapture?.targetOffsetY ?? 0) + targetPosition.y) / Math.max(1, root.glassCapture?.sourceHeight ?? 1),
                width / Math.max(1, root.glassCapture?.sourceWidth ?? 1),
                height / Math.max(1, root.glassCapture?.sourceHeight ?? 1)
            )
            tintColor: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.62)
            radius: valueIndicator.radius
        }

        RowLayout { // Icon on the left, stuff on the right
            id: valueRow
            Layout.margins: 10
            anchors.fill: parent
            spacing: 15

            Item {
                implicitWidth: 30
                implicitHeight: 35
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding

                MaterialShapeWrappedMaterialSymbol {
                    rotation: root.value * 360
                    anchors.centerIn: parent
                    iconSize: Appearance.font.pixelSize.huge
                    shape: root.shape
                    text: root.icon
                }
            }
            ColumnLayout { // Stuff
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: valueIndicatorRightPadding
                spacing: 5

                RowLayout { // Name fill left, value on the right end
                    Layout.leftMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end
                    Layout.rightMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: true
                        text: root.name
                    }

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: false
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                        visible: root.showProgressBar
                        text: Math.round(root.value * 100)
                    }
                }
                
                StyledProgressBar {
                    id: valueProgressBar
                    visible: root.showProgressBar
                    Layout.fillWidth: true
                    value: root.value
                }
            }
        }
    }
}
