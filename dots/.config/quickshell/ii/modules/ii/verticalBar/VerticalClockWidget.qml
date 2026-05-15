import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar as Bar

Item {
    id: root
    implicitHeight: clockColumn.implicitHeight + 10
    implicitWidth: Appearance.sizes.verticalBarWidth

    Connections {
        target: LocalSend
        onCurrentTransferChanged: {
            if (LocalSend.currentTransfer) {
                rootItem.toggleHighlight(true)
            } else {
                rootItem.toggleHighlight(false)
            }
        }
        onDroppedFilesChanged: {
            if (LocalSend.droppedFiles.length > 0) {
                rootItem.toggleHighlight(true)
            } else {
                rootItem.toggleHighlight(false)
            }
        }
    }

    ColumnLayout {
        id: clockColumn
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: DateTime.time.split(/[: ]/)
            delegate: StyledText {
                required property string modelData
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: modelData.match(/am|pm/i) ? 
                    Appearance.font.pixelSize.smaller // Smaller "am"/"pm" text
                    : Appearance.font.pixelSize.large
                color: dropArea.containsDrag ? Appearance.colors.colPrimary : rootItem.highlighted ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                text: modelData.padStart(2, "0")
            }
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (drop) => {
            if (!drop.hasUrls) return
            for (let i = 0; i < drop.urls.length; i++)
                LocalSend.addDroppedFile(drop.urls[i])
            drop.accept(Qt.CopyAction)
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
            Bar.ClockWidgetPopup {
                hoverTarget: mouseArea
            }
        }
        Component {
            id: clockPopupCompact
            Bar.ClockWidgetPopupCompact {
                hoverTarget: mouseArea
            }
        }
    }
}