import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredWidth: 205
    Layout.preferredHeight: implicitHeight
    implicitWidth: 205
    implicitHeight: 150

    radius: Appearance.rounding.normal
    color: root.containerColor

    property string label: ""
    property string value: ""
    property string supportingText: ""
    property string icon: ""
    property string shapeString: "SoftBurst"
    property real progress: -1
    property color containerColor: Appearance.colors.colSurfaceContainerHigh
    property color shapeColor: Appearance.colors.colPrimaryContainer
    property color symbolColor: Appearance.colors.colOnPrimaryContainer
    property color textColor: Appearance.colors.colOnSurface
    property color supportingTextColor: Appearance.colors.colOnSurfaceVariant
    property color progressColor: Appearance.colors.colPrimary
    property color trackColor: Appearance.colors.colSurfaceContainerHighest

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialShape {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                shapeString: root.shapeString
                implicitSize: 42
                color: root.shapeColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.icon
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.symbolColor
                    fill: 1
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                color: root.textColor
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.value
            elide: Text.ElideRight
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.hugeass + 7
            font.weight: Font.Black
            color: root.textColor
        }

        StyledText {
            Layout.fillWidth: true
            text: root.supportingText
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.supportingTextColor
        }

        Item {
            Layout.fillHeight: true
        }

        StyledProgressBar {
            visible: root.progress >= 0
            Layout.fillWidth: true
            value: Math.max(0, Math.min(1, root.progress))
            highlightColor: root.progressColor
            trackColor: root.trackColor
            wavy: false
        }
    }
}
