import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets

Item {
    id: root

    required property var service
    required property var style
    signal backRequested()
    signal chapterSelected(var chapter)
    signal readLatestRequested()

    property bool ascending: false
    property string filterText: ""
    focus: true
    Keys.onEscapePressed: {
        if (filterField.activeFocus) {
            filterField.text = ""
            root.forceActiveFocus()
        } else {
            root.backRequested()
        }
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus()
            event.accepted = true
        } else if (!filterField.activeFocus) {
            if (event.key === Qt.Key_J) {
                chapterList.forceActiveFocus()
                var next = Math.min(chapterList.currentIndex + 1, chapterList.count - 1)
                chapterList.currentIndex = next
                event.accepted = true
            } else if (event.key === Qt.Key_K) {
                chapterList.forceActiveFocus()
                var prev = Math.max(chapterList.currentIndex - 1, 0)
                chapterList.currentIndex = prev
                event.accepted = true
            } else if (event.key === Qt.Key_G) {
                chapterList.forceActiveFocus()
                chapterList.currentIndex = 0
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                chapterList.forceActiveFocus()
                chapterList.currentIndex = chapterList.count - 1
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (chapterList.currentIndex >= 0 && chapterList.currentIndex < chapterList.count) {
                    var ch = root.processedChapters[chapterList.currentIndex]
                    root.chapterSelected(ch)
                    event.accepted = true
                }
            }
        }
    }

    function chapterLabel(value) {
        var match = String(value || "").match(/\d+(\.\d+)?/)
        return match ? match[0] : String(value || "?")
    }

    readonly property var processedChapters: {
        if (!Array.isArray(service.currentChapters) || service.currentChapters.length === 0)
            return []
        var chapters = service.currentChapters.slice()
        var filter = filterText.trim().toLowerCase()
        if (filter) {
            chapters = chapters.filter(function(chapter) {
                return chapterLabel(chapter.chapter).toLowerCase().indexOf(filter) >= 0
                    || String(chapter.title || "").toLowerCase().indexOf(filter) >= 0
            })
        }
        chapters.sort(function(left, right) {
            var a = parseFloat(chapterLabel(left.chapter)) || 0
            var b = parseFloat(chapterLabel(right.chapter)) || 0
            return ascending ? a - b : b - a
        })
        return chapters
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 12

                Text {
                    text: "<"
                    color: root.style.accent
                    font.family: root.style.font
                    font.pixelSize: 18

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.service.currentManga ? root.service.currentManga.title : "MANGA DETAIL"
                    color: root.style.inkStrong
                    font.family: root.style.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: Boolean(root.service.currentManga)
                    Layout.preferredWidth: libraryText.implicitWidth + 20
                    Layout.preferredHeight: 28
                    color: root.service.currentManga && root.service.isInLibrary(root.service.currentManga.id)
                        ? root.style.accent : "transparent"
                    border.color: root.style.accent
                    border.width: 1

                    Text {
                        id: libraryText
                        anchors.centerIn: parent
                        text: root.service.currentManga && root.service.isInLibrary(root.service.currentManga.id)
                            ? "IN LIBRARY" : "ADD"
                        color: root.service.currentManga
                            && root.service.isInLibrary(root.service.currentManga.id)
                            ? root.style.paper : root.style.accent
                        font.family: root.style.font
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var manga = root.service.currentManga
                            if (!manga)
                                return
                            if (root.service.isInLibrary(manga.id))
                                root.service.removeFromLibrary(manga.id)
                            else
                                root.service.addToLibrary(manga)
                        }
                    }
                }

                Rectangle {
                    visible: Boolean(root.service.currentManga && root.service.currentManga.latestChapterId)
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 28
                    color: root.style.accent

                    Text {
                        anchors.centerIn: parent
                        text: "READ LATEST"
                        color: "#ffffff"
                        font.family: root.style.font
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.readLatestRequested()
                    }
                }

                Rectangle {
                    visible: root.service.chaptersLoaded && !root.service.isFetchingChapters
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 28
                    color: root.style.field
                    border.color: root.style.line
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "REFETCH"
                        color: root.style.ink
                        font.family: root.style.font
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.refetchChapters()
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.style.line
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.service.currentManga ? 170 : 0
            visible: height > 0
            clip: true

            Image {
                anchors.fill: parent
                source: root.service.currentManga ? root.service.currentManga.image : ""
                fillMode: Image.PreserveAspectCrop
                opacity: 0.12
            }

            Rectangle {
                anchors.fill: parent
                color: root.style.paper
                opacity: 0.72
            }

            RowLayout {
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 18

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.fillHeight: true
                    color: root.style.field
                    border.color: root.style.line
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.service.currentManga ? root.service.currentManga.image : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        Layout.fillWidth: true
                        text: root.service.currentManga ? root.service.currentManga.title : ""
                        color: root.style.inkStrong
                        font.family: root.style.font
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.service.currentManga
                            ? (root.service.currentManga.authors || []).join(", ") : ""
                        color: root.style.accent
                        font.family: root.style.font
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.service.currentManga ? root.service.currentManga.description : ""
                        color: root.style.ink
                        font.family: root.style.font
                        font.pixelSize: 11
                        lineHeight: 1.25
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        elide: Text.ElideRight
                    }
                    Text {
                        text: root.service.currentManga
                            ? root.service.currentManga.status + "  /  " + root.processedChapters.length + " CHAPTERS"
                            : ""
                        color: root.style.inkSoft
                        font.family: root.style.font
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 28
                            color: root.style.field
                            visible: !root.service.chaptersLoaded

                            Text {
                                anchors.centerIn: parent
                                text: root.service.isFetchingChapters ? "LOADING..." : "LOAD CHAPTERS"
                                color: root.style.ink
                                font.family: root.style.font
                                font.pixelSize: 9
                                font.letterSpacing: 1
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.service.isFetchingChapters)
                                        root.service.fetchChapters()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.style.line
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: Boolean(root.service.currentManga)

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: root.style.field
                    border.color: filterField.activeFocus ? root.style.accent : root.style.line
                    border.width: 1

                    TextField {
                        id: filterField
                        anchors.fill: parent
                        leftPadding: 10
                        rightPadding: 10
                        background: null
                        placeholderText: "filter chapter"
                        placeholderTextColor: root.style.inkSoft
                        color: root.style.inkStrong
                        font.family: root.style.font
                        font.pixelSize: 11
                        onTextChanged: root.filterText = text
                        onAccepted: {
                            if (root.processedChapters.length > 0)
                                root.chapterSelected(root.processedChapters[0])
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 32
                    color: "transparent"
                    border.color: root.style.line
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.ascending ? "OLDEST" : "NEWEST"
                        color: root.style.ink
                        font.family: root.style.font
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.ascending = !root.ascending
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MaterialLoadingIndicator {
                anchors.centerIn: parent
                loading: root.service.isFetchingChapters && root.processedChapters.length === 0
                visible: loading
                implicitSize: 44
            }

            Text {
                anchors.top: parent.verticalCenter
                anchors.topMargin: 30
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.service.chaptersProgress > 0
                    ? "LOADING CHAPTERS " + root.service.chaptersProgress
                    : "LOADING CHAPTERS"
                visible: root.service.isFetchingChapters && root.processedChapters.length === 0
                color: root.style.inkSoft
                font.family: root.style.font
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            ListView {
                id: chapterList
                anchors.fill: parent
                model: root.processedChapters
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 100
                highlight: Rectangle {
                    color: root.style.accent
                    opacity: 0.1
                    radius: 2
                }
                ScrollBar.vertical: ScrollBar {}

                delegate: Item {
                    required property var modelData
                    width: chapterList.width
                    height: 58
                    readonly property var libraryEntry: root.service.currentManga
                        ? root.service.getLibraryEntry(root.service.currentManga.id) : null
                    readonly property bool lastRead: libraryEntry
                        && libraryEntry.lastReadChapterId === modelData.id

                    Rectangle {
                        anchors.fill: parent
                        color: parent.lastRead ? root.style.selected : "transparent"
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 18
                            rightMargin: 18
                        }
                        spacing: 14

                        Text {
                            Layout.preferredWidth: 64
                            text: "CH." + root.chapterLabel(modelData.chapter)
                            color: parent.parent.lastRead ? root.style.accent : root.style.inkStrong
                            font.family: root.style.font
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || ("Chapter " + root.chapterLabel(modelData.chapter))
                                color: root.style.ink
                                font.family: root.style.font
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.publishAt ? String(modelData.publishAt).slice(0, 10) : ""
                                color: root.style.inkSoft
                                font.family: root.style.font
                                font.pixelSize: 9
                            }
                        }
                        Text {
                            text: ">"
                            color: root.style.accent
                            font.family: root.style.font
                            font.pixelSize: 13
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: root.style.lineFaint
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chapterSelected(modelData)
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: root.service.isFetchingDetail

                MaterialLoadingIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    loading: parent.visible
                    visible: loading
                    implicitSize: 44
                }
                Text {
                    text: "FETCHING CHAPTERS"
                    color: root.style.inkSoft
                    font.family: root.style.font
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 420)
                spacing: 12
                visible: root.service.detailError.length > 0 && !root.service.isFetchingDetail

                Text {
                    width: parent.width
                    text: root.service.detailError
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
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.service.retryDetail()
                    }
                }
            }
        }
    }
}
