import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property color foregroundColor: Appearance.colors.colOnLayer1
    property bool showDate: Config.options.bar.verbose
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 10
    implicitHeight: Appearance.sizes.barHeight
    property color colText: dropArea.containsDrag ? Appearance.colors.colPrimary : rootItem.highlighted ? Appearance.colors.colOnPrimary : root.foregroundColor

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
}
