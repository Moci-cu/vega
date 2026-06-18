import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets

Item {
    id: root

    required property var service
    required property var style
    signal mangaSelected(string mangaId)
    property int gridIndex: 0
    readonly property int gridColumns: grid.columns
    focus: true

    function focusSearch() {
        searchField.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 58

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 12

                Text {
                    text: "SEARCH"
                    color: root.style.accent
                    font.family: root.style.font
                    font.pixelSize: 11
                    font.letterSpacing: 3
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: root.style.field
                    border.color: searchField.activeFocus ? root.style.accent : root.style.line
                    border.width: 1

                    TextField {
                        id: searchField
                        anchors.fill: parent
                        leftPadding: 12
                        rightPadding: 12
                        placeholderText: "title / author"
                        color: root.style.inkStrong
                        placeholderTextColor: root.style.inkSoft
                        font.family: root.style.font
                        font.pixelSize: 12
                        selectByMouse: true
                        background: null
                        onTextEdited: searchTimer.restart()
                        onAccepted: root.service.searchManga(text.trim(), true)
                        Keys.onEscapePressed: {
                            text = ""
                            root.service.fetchByOrigin(root.service.currentOrigin, true)
                        }
                    }
                }

                Text {
                    text: root.service.mangaList.length
                    color: root.style.inkSoft
                    font.family: root.style.font
                    font.pixelSize: 11
                }
            }

            Timer {
                id: searchTimer
                interval: 350
                onTriggered: {
                    var query = searchField.text.trim()
                    if (query)
                        root.service.searchManga(query, true)
                    else
                        root.service.fetchByOrigin(root.service.currentOrigin, true)
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.style.line
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            contentWidth: filterRow.implicitWidth + 36
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: filterRow
                anchors.verticalCenter: parent.verticalCenter
                x: 18
                spacing: 8

                Repeater {
                    model: [
                        { label: "HOT", value: "" },
                        { label: "LATEST", value: "latest" },
                        { label: "MANGA", value: "ja" },
                        { label: "MANHWA", value: "ko" },
                        { label: "MANHUA", value: "zh" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected: root.service.currentOrigin === modelData.value
                        width: filterText.implicitWidth + 22
                        height: 26
                        color: selected ? root.style.accent : "transparent"
                        border.color: selected ? root.style.accent : root.style.line
                        border.width: 1

                        Text {
                            id: filterText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.selected ? root.style.paper : root.style.ink
                            font.family: root.style.font
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                root.service.fetchByOrigin(modelData.value, true)
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors {
                    fill: parent
                    margins: 14
                }
                readonly property int columns: width >= 900 ? 5 : width >= 700 ? 4 : 3
                cellWidth: width / columns
                cellHeight: Math.max(210, cellWidth * 1.55)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.service.mangaList
                currentIndex: root.gridIndex
                cacheBuffer: Math.max(0, height)
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 100
                highlight: Item {
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        color: "transparent"
                        border.color: root.style.accent
                        border.width: 2
                        radius: 6
                    }
                }
                ScrollBar.vertical: ScrollBar {}

                onContentYChanged: {
                    if (contentY + height >= contentHeight - cellHeight * 1.5)
                        root.service.fetchNextMangaPage()
                }

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    scale: grid.currentIndex === index ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }

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
                                    source: modelData.image || ""
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

                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        right: parent.right
                                        margins: 8
                                    }
                                    visible: Boolean(modelData.type)
                                    width: typeText.implicitWidth + 12
                                    height: 20
                                    color: root.style.paper
                                    border.color: root.style.accent
                                    border.width: 1

                                    Text {
                                        id: typeText
                                        anchors.centerIn: parent
                                        text: modelData.type || ""
                                        color: root.style.accent
                                        font.family: root.style.font
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 54

                                Text {
                                    anchors {
                                        fill: parent
                                        margins: 9
                                    }
                                    text: modelData.title || ""
                                    color: root.style.inkStrong
                                    font.family: root.style.font
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
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
                visible: root.service.isFetchingManga && root.service.mangaList.length === 0

                MaterialLoadingIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    loading: parent.visible
                    visible: loading
                    implicitSize: 44
                }
                Text {
                    text: "LOADING ARCHIVE"
                    color: root.style.inkSoft
                    font.family: root.style.font
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 420)
                spacing: 12
                visible: root.service.mangaError.length > 0 && !root.service.isFetchingManga

                Text {
                    width: parent.width
                    text: root.service.mangaError
                    color: root.style.accent
                    font.family: root.style.font
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 100
                    height: 30
                    color: "transparent"
                    border.color: root.style.accent
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "RETRY"
                        color: root.style.accent
                        font.family: root.style.font
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.retryList()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.service.backendState === "ready"
                    && !root.service.isFetchingManga
                    && !root.service.mangaError
                    && root.service.mangaList.length === 0
                text: "NO TITLES FOUND"
                color: root.style.inkSoft
                font.family: root.style.font
                font.pixelSize: 12
                font.letterSpacing: 2
            }
        }
    }
}
