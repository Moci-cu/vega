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
    implicitHeight: 172

    radius: Appearance.rounding.normal
    color: root.containerColor

    property string label: ""
    property string value: ""
    property string supportingText: ""
    property string detailText: ""
    property string detailIcon: ""
    property string badgeText: ""
    property string badgeIcon: ""
    property string icon: ""
    property string shapeString: "Cookie9Sided"
    property real progress: 0
    property bool showProgress: true

    property int valueSize: Appearance.font.pixelSize.hugeass * 2
    property color containerColor: Appearance.colors.colPrimaryContainer
    property color accentColor: Appearance.colors.colPrimary
    property color shapeColor: Appearance.colors.colPrimary
    property color symbolColor: Appearance.colors.colOnPrimary
    property color textColor: Appearance.colors.colOnPrimaryContainer
    property color mutedTextColor: Appearance.colors.colOnPrimaryContainer
    property color trackColor: Appearance.colors.colSurfaceContainerHighest
    property color badgeColor: Appearance.colors.colSecondaryContainer
    property color badgeTextColor: Appearance.colors.colOnSecondaryContainer

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Item {
            Layout.preferredWidth: 112
            Layout.preferredHeight: 112
            Layout.alignment: Qt.AlignVCenter

            CircularProgress {
                visible: root.showProgress
                anchors.centerIn: parent
                implicitSize: 112
                lineWidth: 7
                gapAngle: 7
                value: Math.max(0, Math.min(1, root.progress))
                colPrimary: root.accentColor
                colSecondary: root.trackColor
                animationDuration: Appearance.animation.elementMove.duration
            }

            MaterialShape {
                anchors.centerIn: parent
                implicitSize: root.showProgress ? 82 : 96
                shapeString: root.shapeString
                color: root.shapeColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.icon
                    iconSize: root.showProgress ? 38 : 42
                    color: root.symbolColor
                    fill: 1
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.label
                    elide: Text.ElideRight
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.mutedTextColor
                }

                Rectangle {
                    visible: root.badgeText !== ""
                    implicitWidth: badgeRow.implicitWidth + 16
                    implicitHeight: 30
                    radius: Appearance.rounding.full
                    color: root.badgeColor

                    RowLayout {
                        id: badgeRow
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
                            font.family: Appearance.font.family.title
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: root.badgeTextColor
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.value
                elide: Text.ElideRight
                font.family: Appearance.font.family.title
                font.pixelSize: root.valueSize
                font.weight: Font.Black
                color: root.textColor
            }

            StyledText {
                Layout.fillWidth: true
                text: root.supportingText
                elide: Text.ElideRight
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                color: root.textColor
            }

            RowLayout {
                visible: root.detailText !== ""
                Layout.fillWidth: true
                spacing: 5

                MaterialSymbol {
                    visible: root.detailIcon !== ""
                    text: root.detailIcon
                    iconSize: Appearance.font.pixelSize.small
                    color: root.mutedTextColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.detailText
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.mutedTextColor
                }
            }
        }
    }
}
