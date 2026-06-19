import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property bool panelOpen: false
    property bool animRunning: false
    property bool isFullscreen: false
    property real screenW: 1920
    property real screenH: 1080
    property string page: "browse"
    property string detailOrigin: "browse"

    readonly property int normalPanelWidth: Math.min(screenW - 48, 1080)
    readonly property int normalPanelHeight: Math.min(screenH - 48, 820)
    readonly property int panelWidth: isFullscreen ? width : normalPanelWidth
    readonly property int panelHeight: isFullscreen ? height : normalPanelHeight

    QtObject {
        id: mangaStyle
        readonly property string font: Appearance.font.family.main
        readonly property color paper: "#16100c"
        readonly property color card: "#211813"
        readonly property color field: "#4e4540"
        readonly property color selected: "#3b2b22"
        readonly property color ink: "#e8d9cf"
        readonly property color inkStrong: "#fff5ed"
        readonly property color inkSoft: "#b79f93"
        readonly property color accent: Appearance.colors.colPrimary
        readonly property color line: "#3d2d25"
        readonly property color lineFaint: "#332720"
        readonly property int radius: Appearance.rounding.small
        readonly property int windowRadius: root.isFullscreen ? 0 : Appearance.rounding.windowRounding
    }

    MangaService {
        id: service
    }

    function openPanel() {
        if (panelOpen)
            return
        panelOpen = true
        animRunning = true
        panelHost.visible = true
        service.ensureStarted()
        focusTimer.restart()
    }

    function closePanel() {
        if (!panelOpen)
            return
        panelOpen = false
        isFullscreen = false
        animRunning = true
        focusTimer.stop()
        hideDone.restart()
    }

    function togglePanel() {
        if (panelOpen)
            closePanel()
        else
            openPanel()
    }

    function toggleFullscreen() {
        if (!panelOpen)
            openPanel()
        isFullscreen = !isFullscreen
        focusTimer.restart()
    }

    function openBrowseManga(mangaId) {
        root.detailOrigin = "browse"
        root.page = "detail"
        service.fetchMangaDetail(mangaId)
    }

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: panelHost.forceActiveFocus()
    }

    Timer {
        id: hideDone
        interval: 240
        onTriggered: {
            panelHost.visible = false
            root.animRunning = false
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: root.panelOpen ? 0.62 : 0
        visible: panelHost.visible

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    Item {
        id: panelHost
        anchors.centerIn: parent
        width: root.panelWidth
        height: root.panelHeight
        visible: false
        clip: true
        opacity: root.panelOpen ? 1 : 0
        scale: root.panelOpen ? 1 : 0.97
        focus: root.panelOpen
        Keys.onEscapePressed: root.closePanel()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_F) {
                root.toggleFullscreen()
                event.accepted = true
            } else if (root.page === "browse") {
                browseView.forceActiveFocus()
                if (event.key === Qt.Key_Slash) {
                    browseView.focusSearch()
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab) {
                    var origins = ["", "latest", "ja", "ko", "zh"]
                    var idx = origins.indexOf(service.currentOrigin)
                    idx = (idx + 1) % origins.length
                    service.fetchByOrigin(origins[idx], true)
                    event.accepted = true
                } else if (event.key === Qt.Key_J) {
                    browseView.gridIndex = Math.min(browseView.gridIndex + browseView.gridColumns, service.mangaList.length - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_K) {
                    browseView.gridIndex = Math.max(browseView.gridIndex - browseView.gridColumns, 0)
                    event.accepted = true
                } else if (event.key === Qt.Key_H) {
                    browseView.gridIndex = Math.max(browseView.gridIndex - 1, 0)
                    event.accepted = true
                } else if (event.key === Qt.Key_L) {
                    browseView.gridIndex = Math.min(browseView.gridIndex + 1, service.mangaList.length - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (browseView.gridIndex >= 0 && browseView.gridIndex < service.mangaList.length) {
                        root.openBrowseManga(service.mangaList[browseView.gridIndex].id)
                        event.accepted = true
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            color: mangaStyle.paper
            border.color: mangaStyle.line
            border.width: root.isFullscreen ? 0 : 1
            radius: mangaStyle.windowRadius
            clip: true
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                visible: root.page !== "reader"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 18
                        rightMargin: 18
                    }
                    spacing: 14

                    MaterialSymbol {
                        text: "auto_stories"
                        color: mangaStyle.accent
                        iconSize: 18
                        fill: 1
                    }
                    Text {
                        text: "MANGA ARCHIVE"
                        color: mangaStyle.inkStrong
                        font.family: mangaStyle.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 3
                    }
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: service.backendState === "ready" ? "#4a9" : service.backendState === "connecting" ? "#ca3" : service.backendState === "error" ? "#c44" : "#666"
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [
                            { label: "BROWSE", value: "browse" },
                            { label: "LIBRARY", value: "library" }
                        ]

                        delegate: Item {
                            required property var modelData
                            Layout.preferredWidth: tabText.implicitWidth + 18
                            Layout.fillHeight: true
                            readonly property bool selected: root.page === modelData.value
                                || (root.page === "detail" && root.detailOrigin === modelData.value)

                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.selected ? mangaStyle.accent : mangaStyle.inkSoft
                                font.family: mangaStyle.font
                                font.pixelSize: 10
                                font.letterSpacing: 2
                            }
                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                height: 2
                                color: mangaStyle.accent
                                visible: parent.selected
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.page = modelData.value
                            }
                        }
                    }

                    MaterialSymbol {
                        text: "close"
                        color: mangaStyle.inkSoft
                        iconSize: 20
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePanel()
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: mangaStyle.line
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                BrowseView {
                    id: browseView
                    anchors.fill: parent
                    visible: root.page === "browse"
                    service: service
                    style: mangaStyle
                    onVisibleChanged: {
                        if (visible)
                            browseView.forceActiveFocus()
                    }
                    onMangaSelected: function(mangaId) {
                        root.openBrowseManga(mangaId)
                    }
                }

                LibraryView {
                    anchors.fill: parent
                    visible: root.page === "library"
                    service: service
                    style: mangaStyle
                    onMangaSelected: function(mangaId) {
                        root.detailOrigin = "library"
                        root.page = "detail"
                        service.fetchMangaDetail(mangaId)
                    }
                }

                DetailView {
                    id: detailView
                    anchors.fill: parent
                    visible: root.page === "detail"
                    service: service
                    style: mangaStyle
                    onVisibleChanged: {
                        if (visible)
                            detailView.forceActiveFocus()
                    }
                    onBackRequested: root.page = root.detailOrigin
                    onChapterSelected: function(chapter) {
                        service.fetchChapterPages(chapter.id)
                        if (service.currentManga)
                            service.updateLastRead(
                                service.currentManga.id,
                                chapter.id,
                                chapter.chapter
                            )
                        root.page = "reader"
                    }
                    onReadLatestRequested: {
                        if (service.currentManga && service.currentManga.latestChapterId) {
                            service.fetchChapterPages(service.currentManga.latestChapterId)
                            root.page = "reader"
                        }
                    }
                }

                ReaderView {
                    id: readerView
                    anchors.fill: parent
                    visible: root.page === "reader"
                    service: service
                    style: mangaStyle
                    onVisibleChanged: {
                        if (visible)
                            readerView.pagesView.forceActiveFocus()
                    }
                    onProgressSaved: function(mangaId, chapterId, chapterNum, page) {
                        service.updateLastRead(mangaId, chapterId, chapterNum, page)
                    }
                    onBackRequested: {
                        service.clearChapterPages()
                        root.page = "detail"
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: service.backendState === "connecting"
                        || service.backendState === "error"
                    color: mangaStyle.paper
                    z: 10

                    Column {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 460)
                        spacing: 14

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: service.backendState === "connecting" ? "CONNECTING ARCHIVE" : "BACKEND ERROR"
                            color: service.backendState === "error" ? mangaStyle.accent : mangaStyle.inkStrong
                            font.family: mangaStyle.font
                            font.pixelSize: 13
                            font.letterSpacing: 3
                        }
                        Text {
                            width: parent.width
                            visible: service.backendState === "error"
                            text: service.backendError
                            color: mangaStyle.inkSoft
                            font.family: mangaStyle.font
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: service.backendState === "error"
                            width: 100
                            height: 30
                            color: "transparent"
                            border.color: mangaStyle.accent
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "RETRY"
                                color: mangaStyle.accent
                                font.family: mangaStyle.font
                                font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: service.retryBackend()
                            }
                        }
                    }
                }
            }
        }
    }
}
