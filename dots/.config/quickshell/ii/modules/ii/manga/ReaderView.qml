import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets

Item {
    id: root

    required property var service
    required property var style
    signal backRequested()
    signal progressSaved(string mangaId, string chapterId, string chapterNum, int page)

    property bool headerVisible: true
    property bool gPending: false
    property alias pagesView: pages
    focus: true

    Timer {
        id: gTimer
        interval: 500
        onTriggered: root.gPending = false
    }

    Timer {
        id: saveTimer
        interval: 2000
        onTriggered: {
            if (!root.service.currentManga || root.service.chapterPages.length === 0)
                return
            var page = pages.currentIndex >= 0 ? pages.currentIndex + 1 : 1
            var chapterId = root.service.currentChapterId
            var chapterNum = ""
            var chapters = root.service.currentChapters
            for (var i = 0; i < chapters.length; i++) {
                if (chapters[i].id === chapterId) {
                    chapterNum = chapters[i].chapter
                    break
                }
            }
            root.progressSaved(root.service.currentManga.id, chapterId, chapterNum, page)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#090909"
    }

    ListView {
        id: pages
        anchors {
            fill: parent
            topMargin: root.headerVisible ? header.height : 0
        }
        model: root.service.chapterPages
        spacing: 4
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: Math.max(0, height * 2)
        ScrollBar.vertical: ScrollBar {}
        onCurrentIndexChanged: saveTimer.restart()

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        onContentYChanged: {
            var candidate = indexAt(width / 2, contentY + height / 2)
            if (candidate >= 0)
                currentIndex = candidate
        }

        TapHandler {
            onTapped: root.headerVisible = !root.headerVisible
        }

        Keys.onPressed: function(event) {
            var scrollDelta = height * 0.65
            if (event.key === Qt.Key_J || event.key === Qt.Key_Down || event.key === Qt.Key_Space) {
                contentY = Math.min(contentHeight - height, contentY + scrollDelta)
                event.accepted = true
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                contentY = Math.max(0, contentY - scrollDelta)
                event.accepted = true
            } else if (event.key === Qt.Key_G) {
                if (event.modifiers & Qt.ShiftModifier) {
                    positionViewAtEnd()
                    root.gPending = false
                } else if (root.gPending) {
                    positionViewAtBeginning()
                    root.gPending = false
                } else {
                    root.gPending = true
                    gTimer.restart()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_H) {
                root.headerVisible = !root.headerVisible
                event.accepted = true
            } else if (event.key === Qt.Key_Q || event.key === Qt.Key_Escape) {
                root.backRequested()
                event.accepted = true
            }
        }

        delegate: Item {
            required property var modelData
            width: pages.width
            height: pageImage.status === Image.Ready && pageImage.sourceSize.height > 0
                ? pageImage.sourceSize.height * (720 / pageImage.sourceSize.width)
                : 720 * 1.42

            Rectangle {
                anchors.fill: parent
                color: "#111111"
            }

            Image {
                id: pageImage
                width: Math.min(parent.width, 720)
                height: sourceSize.height > 0 ? sourceSize.height * (width / sourceSize.width) : width * 1.42
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                source: modelData.url || ""
                fillMode: Image.Stretch
                asynchronous: true
                cache: true
            }

            MaterialLoadingIndicator {
                anchors.centerIn: parent
                visible: pageImage.status === Image.Loading
                loading: visible
                implicitSize: 44
            }

            Text {
                anchors.centerIn: parent
                visible: pageImage.status === Image.Error
                text: "PAGE " + (modelData.index + 1) + " FAILED"
                color: root.style.accent
                font.family: root.style.font
                font.pixelSize: 10
                font.letterSpacing: 2
            }
        }
    }

    Rectangle {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 54
        color: root.style.paper
        opacity: root.headerVisible ? 0.96 : 0
        visible: opacity > 0
        z: 5

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

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
                text: root.service.currentManga ? root.service.currentManga.title : "READER"
                color: root.style.inkStrong
                font.family: root.style.font
                font.pixelSize: 12
                font.letterSpacing: 1
                elide: Text.ElideRight
            }
            Text {
                text: root.service.chapterPages.length
                    ? (Math.max(0, pages.currentIndex) + 1)
                        + " / " + root.service.chapterPages.length
                    : ""
                color: root.style.inkSoft
                font.family: root.style.font
                font.pixelSize: 10
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: root.style.line
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 3
        color: "#222222"
        visible: root.service.chapterPages.length > 0
        z: 6

        Rectangle {
            width: parent.width * Math.max(0,
                (Math.max(0, pages.currentIndex) + 1)
                    / root.service.chapterPages.length)
            height: parent.height
            color: root.style.accent
            Behavior on width {
                NumberAnimation { duration: 120 }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: root.service.isFetchingPages
        z: 4

        MaterialLoadingIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            loading: parent.visible
            visible: loading
            implicitSize: 44
        }
        Text {
            text: "LOADING PAGES"
            color: "#d8d0b8"
            font.family: root.style.font
            font.pixelSize: 10
            font.letterSpacing: 2
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 420)
        spacing: 12
        visible: root.service.pagesError.length > 0 && !root.service.isFetchingPages
        z: 4

        Text {
            width: parent.width
            text: root.service.pagesError
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
                onClicked: root.service.retryPages()
            }
        }
    }
}
