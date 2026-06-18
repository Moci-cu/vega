import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets

Item {
    id: root

    required property var service
    required property var style
    signal mangaSelected(string mangaId)

    GridView {
        id: grid
        anchors {
            fill: parent
            margins: 14
        }
        readonly property int columns: width >= 900 ? 5 : width >= 700 ? 4 : 3
        cellWidth: width / columns
        cellHeight: Math.max(225, cellWidth * 1.7)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.service.libraryList
        ScrollBar.vertical: ScrollBar {}

        delegate: Item {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors {
                    fill: parent
                    margins: 7
                }
                color: root.style.card
                border.color: root.style.line
                border.width: 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Image {
                            id: cover
                            anchors.fill: parent
                            source: modelData.coverUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: cover.status !== Image.Ready
                            color: root.style.field
                            MaterialLoadingIndicator {
                                anchors.centerIn: parent
                                loading: parent.visible && cover.status === Image.Loading
                                visible: loading
                                implicitSize: 40
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70

                        Column {
                            anchors {
                                fill: parent
                                margins: 9
                            }
                            spacing: 4

                            Text {
                                width: parent.width
                                text: modelData.title || ""
                                color: root.style.inkStrong
                                font.family: root.style.font
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.lastReadChapterNum
                                    ? "CH." + modelData.lastReadChapterNum
                                    : "NEW"
                                color: modelData.lastReadChapterNum ? root.style.accent : root.style.inkSoft
                                font.family: root.style.font
                                font.pixelSize: 9
                                font.letterSpacing: 1
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.mangaSelected(modelData.id)
                    Rectangle {
                        anchors.fill: parent
                        color: root.style.accent
                        opacity: parent.pressed ? 0.14 : parent.containsMouse ? 0.06 : 0
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: root.service.libraryLoaded && root.service.libraryList.length === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "LIBRARY EMPTY"
            color: root.style.inkStrong
            font.family: root.style.font
            font.pixelSize: 14
            font.letterSpacing: 3
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Add a title from its detail page"
            color: root.style.inkSoft
            font.family: root.style.font
            font.pixelSize: 11
        }
    }

    MaterialLoadingIndicator {
        anchors.centerIn: parent
        visible: !root.service.libraryLoaded
        loading: visible
        implicitSize: 44
    }
}
