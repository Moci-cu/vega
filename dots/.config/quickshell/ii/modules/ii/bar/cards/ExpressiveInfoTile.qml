import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    implicitWidth: 420
    implicitHeight: 76

    radius: Appearance.rounding.normal
    color: root.containerColor

    property string label: ""
    property string value: ""
    property string icon: ""
    property string shapeString: "Clover4Leaf"
    property string badgeText: ""
    property string badgeIcon: ""
    property color containerColor: Appearance.colors.colSurfaceContainerHigh
    property color shapeColor: Appearance.colors.colSecondaryContainer
    property color symbolColor: Appearance.colors.colOnSecondaryContainer
    property color textColor: Appearance.colors.colOnSurface
    property color labelColor: Appearance.colors.colOnSurfaceVariant
    property color badgeColor: Appearance.colors.colSurfaceContainerHighest
    property color badgeTextColor: Appearance.colors.colOnSurface

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        MaterialShape {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            shapeString: root.shapeString
            implicitSize: 48
            color: root.shapeColor

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.icon
                iconSize: Appearance.font.pixelSize.huge
                color: root.symbolColor
                fill: 1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.labelColor
            }

            StyledText {
                Layout.fillWidth: true
                text: root.value
                elide: Text.ElideRight
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                color: root.textColor
            }
        }

        Rectangle {
            visible: root.badgeText !== ""
            implicitWidth: tileBadgeRow.implicitWidth + 16
            implicitHeight: 30
            radius: Appearance.rounding.full
            color: root.badgeColor

            RowLayout {
                id: tileBadgeRow
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    visible: root.badgeIcon !== ""
                    text: root.badgeIcon
                    iconSize: Appearance.font.pixelSize.small
                    color: root.badgeTextColor
                    fill: 1
                }

                StyledText {
                    text: root.badgeText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: root.badgeTextColor
                }
            }
        }
    }
}
