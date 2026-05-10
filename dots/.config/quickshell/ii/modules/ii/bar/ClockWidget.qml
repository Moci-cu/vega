import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool showDate: Config.options.bar.verbose
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 10
    implicitHeight: Appearance.sizes.barHeight
    property color colText: LocalSend.currentTransfer ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1

    Connections {
        target: LocalSend
        onCurrentTransferChanged: {
            if (LocalSend.currentTransfer) {
                rootItem.toggleHighlight(true)
            } else {
                rootItem.toggleHighlight(false)
            }
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.large
            color: root.colText
            text: DateTime.time
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colText
            text: "•"
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colText
            text: DateTime.longDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        Loader {
            active: true
            sourceComponent: Config.options.bar.tooltips.compactPopups ? clockPopupCompact : clockPopup
        }
        Component {
            id: clockPopup
            ClockWidgetPopup {
                hoverTarget: mouseArea
            }
        }
        Component {
            id: clockPopupCompact
            ClockWidgetPopupCompact {
                hoverTarget: mouseArea
            }
        }
    }
}
