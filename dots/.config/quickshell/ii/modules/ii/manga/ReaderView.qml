import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property var service
    required property var style
    signal backRequested()
    signal previousChapterRequested()
    signal chapterListRequested()
    signal nextChapterRequested()
    signal progressSaved(string mangaId, string chapterId, string chapterNum, int page)

    property bool headerVisible: true
    property bool gPending: false
    property var pageSizeCache: ({})
    property alias pagesView: pages
    readonly property var sortedChapters: {
        if (!Array.isArray(service.currentChapters))
            return []
        return service.currentChapters.slice().sort(function(left, right) {
            return root.chapterNumber(left) - root.chapterNumber(right)
        })
    }
    readonly property int currentChapterIndex: {
        if (!service.currentChapterId)
            return -1
        for (var i = 0; i < sortedChapters.length; i++) {
            if (sortedChapters[i].id === service.currentChapterId)
                return i
        }
        return -1
    }
    readonly property bool hasPreviousChapter: currentChapterIndex > 0
    readonly property bool hasNextChapter: currentChapterIndex >= 0
        && currentChapterIndex < sortedChapters.length - 1
    focus: true

    function chapterNumber(chapter) {
        var match = String(chapter && chapter.chapter ? chapter.chapter : "0").match(/\d+(\.\d+)?/)
        return match ? parseFloat(match[0]) : 0
    }

    function currentChapterLabel() {
        if (currentChapterIndex < 0)
            return ""
        return "CH." + sortedChapters[currentChapterIndex].chapter
    }

    function hideChrome() {
        headerVisible = false
    }

    function showChrome() {
        headerVisible = true
    }

    function toggleChrome() {
        headerVisible = !headerVisible
    }

    function pageCacheKey(modelData) {
        return root.service.currentChapterId + ":" + (modelData && modelData.index !== undefined ? modelData.index : "")
    }

    function cachedPageRatio(modelData) {
        var entry = root.pageSizeCache[root.pageCacheKey(modelData)]
        return entry && entry.width > 0 && entry.height > 0 ? entry.height / entry.width : 1.42
    }

    function rememberPageSize(modelData, width, height) {
        if (width <= 0 || height <= 0)
            return
        var key = root.pageCacheKey(modelData)
        var current = root.pageSizeCache[key]
        if (current && current.width === width && current.height === height)
            return
        var nextCache = Object.assign({}, root.pageSizeCache)
        nextCache[key] = { width: width, height: height }
        root.pageSizeCache = nextCache
        pageColumn.forceLayout()
        pages.clampContentY()
        pages.updateCurrentIndex()
    }

    component ReaderCircleButton: RippleButton {
        id: buttonRoot

        required property string iconName
        property bool available: true
        property bool emphasized: false

        readonly property real baseSize: 44

        Layout.preferredWidth: baseSize
        Layout.preferredHeight: baseSize
        implicitWidth: baseSize
        implicitHeight: baseSize
        enabled: available
        opacity: available ? 1 : 0.68
        scale: down ? 0.94 : hovered && available ? 1.025 : 1
        buttonRadius: Appearance.rounding.full
        buttonRadiusPressed: Appearance.rounding.normal
        rippleDuration: 520
        colBackground: emphasized ? Appearance.colors.colPrimaryContainer : "transparent"
        colBackgroundHover: emphasized ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colSurfaceContainerHighestHover
        colRipple: emphasized ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colSurfaceContainerHighestActive

        Behavior on scale {
            animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
        }

        contentItem: Item {
            implicitWidth: buttonRoot.baseSize
            implicitHeight: buttonRoot.baseSize

            MaterialSymbol {
                anchors.centerIn: parent
                text: buttonRoot.iconName
                iconSize: 24
                color: buttonRoot.emphasized
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }
    }

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

    Connections {
        target: root.service
        function onCurrentChapterIdChanged() {
            root.pageSizeCache = ({})
            Qt.callLater(function() {
                pages.contentY = 0
                pages.currentIndex = 0
            })
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#090909"
    }

    Flickable {
        id: pages
        property int currentIndex: 0
        readonly property real lazyMargin: Math.max(height * 2.5, 1600)

        anchors {
            fill: parent
            topMargin: root.headerVisible ? header.height : 0
        }
        contentWidth: width
        contentHeight: pageColumn.height
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        onCurrentIndexChanged: saveTimer.restart()
        onMovementStarted: root.hideChrome()
        onContentHeightChanged: clampContentY()
        onHeightChanged: clampContentY()
        onContentYChanged: currentIndexTimer.restart()

        Timer {
            id: currentIndexTimer
            interval: 60
            repeat: false
            onTriggered: pages.updateCurrentIndex()
        }

        function clampContentY() {
            var maxY = Math.max(0, contentHeight - height)
            if (contentY > maxY)
                contentY = maxY
            else if (contentY < 0)
                contentY = 0
        }

        function positionViewAtBeginning() {
            contentY = 0
            updateCurrentIndex()
        }

        function positionViewAtEnd() {
            contentY = Math.max(0, contentHeight - height)
            updateCurrentIndex()
        }

        function updateCurrentIndex() {
            var pageCount = root.service.chapterPages.length
            if (pageCount <= 0) {
                currentIndex = 0
                return
            }

            var centerY = contentY + height / 2
            var candidate = Math.min(currentIndex, pageCount - 1)
            for (var i = 0; i < pageCount; i++) {
                var item = pageRepeater.itemAt(i)
                if (!item)
                    continue
                if (centerY >= item.y && centerY <= item.y + item.height) {
                    candidate = i
                    break
                }
                if (item.y < centerY)
                    candidate = i
            }

            if (currentIndex !== candidate)
                currentIndex = candidate
        }

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        TapHandler {
            onTapped: root.showChrome()
        }

        Keys.onPressed: function(event) {
            var scrollDelta = height * 0.15
            if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                root.hideChrome()
                contentY = Math.min(contentHeight - height, contentY + scrollDelta)
                event.accepted = true
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                root.hideChrome()
                contentY = Math.max(0, contentY - scrollDelta)
                event.accepted = true
            } else if (event.key === Qt.Key_G) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.hideChrome()
                    positionViewAtEnd()
                    root.gPending = false
                } else if (root.gPending) {
                    root.hideChrome()
                    positionViewAtBeginning()
                    root.gPending = false
                } else {
                    root.gPending = true
                    gTimer.restart()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_H) {
                if (root.hasPreviousChapter)
                    root.previousChapterRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_L) {
                if (root.hasNextChapter)
                    root.nextChapterRequested()
                event.accepted = true
            } else if (event.key === Qt.Key_Space) {
                root.toggleChrome()
                event.accepted = true
            } else if (event.key === Qt.Key_Q || event.key === Qt.Key_Escape) {
                root.backRequested()
                event.accepted = true
            }
        }

        Column {
            id: pageColumn
            width: pages.width
            spacing: 4

            Repeater {
                id: pageRepeater
                model: root.service.chapterPages

                delegate: Item {
                    id: pageDelegate
                    required property var modelData
                    property int retryAttempts: 0
                    property int retryNonce: 0
                    property bool imageEverLoaded: false

                    readonly property real imageWidth: Math.max(1, Math.min(pages.width, 720))
                    readonly property real estimatedHeight: imageWidth * root.cachedPageRatio(modelData)
                    readonly property bool nearViewport: y + estimatedHeight >= pages.contentY - pages.lazyMargin
                        && y <= pages.contentY + pages.height + pages.lazyMargin
                    readonly property bool hasImageSize: pageImage.status === Image.Ready
                        && pageImage.sourceSize.width > 0
                        && pageImage.sourceSize.height > 0
                    readonly property real imageHeight: hasImageSize
                        ? pageImage.sourceSize.height * (imageWidth / pageImage.sourceSize.width)
                        : estimatedHeight

                    width: pages.width
                    height: imageHeight

                    Rectangle {
                        anchors.fill: parent
                        color: "#111111"
                    }

                    Image {
                        id: pageImage
                        width: pageDelegate.imageWidth
                        height: pageDelegate.imageHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        source: modelData.url && pageDelegate.nearViewport
                            ? modelData.url + (pageDelegate.retryNonce > 0 ? "&retry=" + pageDelegate.retryNonce : "")
                            : ""
                        fillMode: Image.Stretch
                        asynchronous: true
                        cache: true

                        onStatusChanged: {
                            if (status === Image.Ready) {
                                pageDelegate.retryAttempts = 0
                                pageDelegate.imageEverLoaded = true
                                root.rememberPageSize(modelData, sourceSize.width, sourceSize.height)
                            } else if (status === Image.Error && pageDelegate.retryAttempts < 2) {
                                pageRetryTimer.restart()
                            }
                        }
                    }

                    Timer {
                        id: pageRetryTimer
                        interval: 700 + pageDelegate.retryAttempts * 600
                        repeat: false
                        onTriggered: pageDelegate.retryPage()
                    }

                    function retryPage() {
                        pageDelegate.retryAttempts++
                        pageDelegate.retryNonce = Date.now()
                    }

                    MaterialLoadingIndicator {
                        anchors.centerIn: parent
                        visible: pageImage.status === Image.Loading
                        loading: visible
                        implicitSize: 44
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: pageImage.status === Image.Error
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "PAGE " + (modelData.index + 1) + " FAILED"
                            color: root.style.accent
                            font.family: root.style.font
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 84
                            height: 28
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
                                onClicked: pageDelegate.retryPage()
                            }
                        }
                    }
                }
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
        id: chapterBadge
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: readerControls.top
            bottomMargin: 12
        }
        width: chapterBadgeContent.implicitWidth + 22
        height: 30
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimaryContainer
        opacity: root.headerVisible && root.currentChapterLabel().length > 0 ? 1 : 0
        visible: opacity > 0
        z: 7

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        RowLayout {
            id: chapterBadgeContent
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: "auto_stories"
                iconSize: 16
                color: Appearance.colors.colOnPrimaryContainer
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: "READING " + root.currentChapterLabel()
                color: Appearance.colors.colOnPrimaryContainer
                font.family: root.style.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 0.3
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Rectangle {
        id: readerControls
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 34
        }
        width: controlsRow.implicitWidth + 14
        height: 58
        radius: Appearance.rounding.full
        color: Appearance.m3colors.m3surfaceContainerHigh
        opacity: root.headerVisible ? 1 : 0
        visible: opacity > 0
        z: 7

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        RowLayout {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 4

            ReaderCircleButton {
                iconName: "chevron_left"
                available: root.hasPreviousChapter
                onClicked: root.previousChapterRequested()
            }

            ReaderCircleButton {
                iconName: "menu"
                emphasized: true
                onClicked: root.chapterListRequested()
            }

            ReaderCircleButton {
                iconName: "chevron_right"
                available: root.hasNextChapter
                onClicked: root.nextChapterRequested()
            }
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
