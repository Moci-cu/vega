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
    signal continueReadingRequested(var entry)
    signal readLatestRequested()

    property bool ascending: false
    property string filterText: ""
    readonly property var manga: service.currentManga
    readonly property var mangaTags: manga && Array.isArray(manga.tags) ? manga.tags : []
    readonly property var mangaAuthors: manga && Array.isArray(manga.authors) ? manga.authors : []
    readonly property var libraryEntry: manga ? service.getLibraryEntry(manga.id) : null
    readonly property bool hasReadingProgress: Boolean(libraryEntry && libraryEntry.lastReadChapterId)

    focus: true
    clip: true
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
                chapterList.currentIndex = Math.min(chapterList.currentIndex + 1, chapterList.count - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_K) {
                chapterList.forceActiveFocus()
                chapterList.currentIndex = Math.max(chapterList.currentIndex - 1, 0)
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
                    root.chapterSelected(root.processedChapters[chapterList.currentIndex])
                    event.accepted = true
                }
            }
        }
    }

    function chapterLabel(value) {
        var match = String(value || "").match(/\d+(\.\d+)?/)
        return match ? match[0] : String(value || "?")
    }

    function authorsText() {
        return mangaAuthors.length > 0 ? mangaAuthors.join(", ") : "Unknown author"
    }

    function chapterDate(chapter) {
        return chapter && chapter.publishAt ? String(chapter.publishAt).slice(0, 10) : "Unknown date"
    }

    function toggleLibrary() {
        if (!manga)
            return
        if (service.isInLibrary(manga.id))
            service.removeFromLibrary(manga.id)
        else
            service.addToLibrary(manga)
    }

    function progressText() {
        if (!hasReadingProgress)
            return ""
        return libraryEntry.lastReadChapterNum ? "CH." + libraryEntry.lastReadChapterNum : "SAVED CHAPTER"
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

    component DetailButton: Rectangle {
        id: buttonRoot

        property string label: ""
        property string icon: ""
        property bool primary: false
        readonly property bool hasIcon: icon.length > 0
        readonly property bool hasLabel: label.length > 0
        signal clicked()

        implicitWidth: Math.max(44, buttonText.implicitWidth + (hasIcon && hasLabel ? 44 : hasLabel ? 24 : 0))
        implicitHeight: 36
        radius: 3
        color: !enabled ? root.style.field : primary ? root.style.accent : root.style.field
        border.color: primary ? root.style.accent : root.style.line
        border.width: primary ? 0 : 1
        opacity: enabled ? 1 : 0.45

        RowLayout {
            anchors.centerIn: parent
            spacing: buttonRoot.hasIcon && buttonRoot.hasLabel ? 8 : 0

            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: buttonRoot.hasIcon ? 18 : 0
                Layout.preferredHeight: 18
                visible: buttonRoot.hasIcon

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: buttonRoot.icon
                    iconSize: 18
                    color: buttonRoot.primary ? "#ffffff" : root.style.inkStrong
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                id: buttonText
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 18
                visible: buttonRoot.hasLabel
                text: buttonRoot.label
                color: buttonRoot.primary ? "#ffffff" : root.style.inkStrong
                font.family: root.style.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: buttonRoot.enabled
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: buttonRoot.clicked()

            Rectangle {
                anchors.fill: parent
                radius: parent.parent.radius
                color: "#ffffff"
                opacity: parent.pressed ? 0.12 : parent.containsMouse ? 0.06 : 0
            }
        }
    }

    component MetaChip: Rectangle {
        id: chipRoot

        property string label: ""
        property bool accent: false

        implicitWidth: chipText.implicitWidth + 14
        implicitHeight: 22
        radius: 3
        color: accent ? root.style.accent : root.style.field
        border.color: accent ? root.style.accent : root.style.line
        border.width: 1

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chipRoot.label
            color: chipRoot.accent ? root.style.paper : root.style.ink
            font.family: root.style.font
            font.pixelSize: 9
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }

    component InfoBlock: Column {
        id: infoRoot

        property string title: ""
        property var values: []

        spacing: 7
        width: parent ? parent.width : 240
        visible: values.length > 0

        Text {
            text: infoRoot.title
            color: root.style.inkStrong
            font.family: root.style.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }

        Flow {
            width: parent.width
            spacing: 7

            Repeater {
                model: infoRoot.values

                MetaChip {
                    required property string modelData
                    label: modelData
                }
            }
        }
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
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 12

                MaterialSymbol {
                    text: "arrow_back"
                    iconSize: 20
                    color: root.style.accent

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: manga ? manga.title : "MANGA DETAIL"
                    color: root.style.inkStrong
                    font.family: root.style.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                    elide: Text.ElideRight
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
            Layout.preferredHeight: manga ? 260 : 0
            visible: Boolean(manga)
            clip: true

            Image {
                anchors.fill: parent
                source: manga ? manga.image : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.24
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#201713" }
                    GradientStop { position: 0.55; color: "#251b16" }
                    GradientStop { position: 1.0; color: root.style.paper }
                }
                opacity: 0.88
            }

            RowLayout {
                anchors {
                    fill: parent
                    margins: 18
                }
                spacing: 22

                Rectangle {
                    Layout.preferredWidth: 136
                    Layout.preferredHeight: 204
                    Layout.alignment: Qt.AlignTop
                    color: root.style.field
                    border.color: root.style.line
                    border.width: 1
                    radius: 4
                    clip: true

                    Image {
                        id: heroCover
                        anchors.fill: parent
                        source: manga ? manga.image : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    MaterialLoadingIndicator {
                        anchors.centerIn: parent
                        loading: heroCover.status === Image.Loading
                        visible: loading
                        implicitSize: 40
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: manga ? manga.title : ""
                        color: root.style.inkStrong
                        font.family: root.style.font
                        font.pixelSize: 30
                        font.weight: Font.Bold
                        lineHeight: 0.92
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.authorsText()
                        color: root.style.ink
                        font.family: root.style.font
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        MetaChip {
                            label: manga ? manga.status : ""
                            accent: true
                        }
                        MetaChip {
                            visible: Boolean(manga && manga.type)
                            label: manga && manga.type ? manga.type : ""
                        }
                        MetaChip {
                            label: root.processedChapters.length + " CHAPTERS"
                        }
                        MetaChip {
                            visible: Boolean(manga && manga.rating)
                            label: manga && manga.rating ? "RATING " + manga.rating : ""
                        }
                        MetaChip {
                            visible: root.hasReadingProgress
                            label: "READ " + root.progressText()
                            accent: true
                        }
                        Repeater {
                            model: root.mangaTags.slice(0, 4)

                            MetaChip {
                                required property string modelData
                                label: modelData
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        text: manga ? manga.description : ""
                        color: root.style.ink
                        font.family: root.style.font
                        font.pixelSize: 12
                        lineHeight: 1.25
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        DetailButton {
                            Layout.preferredWidth: 156
                            Layout.preferredHeight: 36
                            label: manga && service.isInLibrary(manga.id) ? "In Library" : "Add To Library"
                            icon: manga && service.isInLibrary(manga.id) ? "bookmark_added" : "bookmark_add"
                            primary: true
                            enabled: Boolean(manga)
                            onClicked: root.toggleLibrary()
                        }

                        DetailButton {
                            Layout.preferredWidth: 156
                            Layout.preferredHeight: 36
                            label: root.hasReadingProgress ? "Continue Reading" : "Start Reading"
                            icon: root.hasReadingProgress ? "history_edu" : "menu_book"
                            enabled: Boolean(manga && (manga.latestChapterId || root.hasReadingProgress))
                            onClicked: {
                                if (root.hasReadingProgress)
                                    root.continueReadingRequested(root.libraryEntry)
                                else
                                    root.readLatestRequested()
                            }
                        }

                        DetailButton {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 36
                            label: ""
                            icon: "refresh"
                            enabled: service.chaptersLoaded && !service.isFetchingChapters
                            onClicked: service.refetchChapters()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 16
            spacing: 18
            visible: Boolean(manga)

            Flickable {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                visible: root.width >= 860
                clip: true
                contentWidth: width
                contentHeight: infoColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: infoColumn
                    width: parent.width
                    spacing: 18

                    InfoBlock {
                        title: "AUTHOR"
                        values: root.mangaAuthors.length > 0 ? root.mangaAuthors : ["Unknown"]
                    }

                    InfoBlock {
                        title: "STATUS"
                        values: manga ? [manga.status] : []
                    }

                    InfoBlock {
                        title: "GENRES"
                        values: root.mangaTags.length > 0 ? root.mangaTags : ["Uncategorized"]
                    }

                    InfoBlock {
                        title: "CHAPTERS"
                        values: [String(root.processedChapters.length)]
                    }

                    InfoBlock {
                        title: "PROGRESS"
                        values: root.hasReadingProgress ? [root.progressText()] : ["Not started"]
                    }

                    InfoBlock {
                        title: "RATING"
                        values: manga && manga.rating ? [manga.rating] : []
                    }

                    InfoBlock {
                        title: "LATEST"
                        values: root.processedChapters.length > 0
                            ? ["Ch. " + root.chapterLabel(root.processedChapters[0].chapter)]
                            : ["Not loaded"]
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Chapters"
                        color: root.style.inkStrong
                        font.family: root.style.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    DetailButton {
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 36
                        label: root.ascending ? "Ascending" : "Descending"
                        icon: "sort"
                        onClicked: root.ascending = !root.ascending
                    }

                    DetailButton {
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 36
                        label: service.chaptersLoaded && !service.isFetchingChapters ? "Refetch" : "Chapters"
                        icon: service.chaptersLoaded && !service.isFetchingChapters ? "refresh" : "format_list_bulleted"
                        enabled: !service.isFetchingChapters
                        onClicked: service.chaptersLoaded ? service.refetchChapters() : service.fetchChapters()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        color: root.style.field
                        border.color: filterField.activeFocus ? root.style.accent : root.style.line
                        border.width: 1
                        radius: 3

                        TextField {
                            id: filterField
                            anchors.fill: parent
                            leftPadding: 11
                            rightPadding: 11
                            background: null
                            placeholderText: "filter chapter"
                            placeholderTextColor: root.style.inkSoft
                            color: root.style.inkStrong
                            font.family: root.style.font
                            font.pixelSize: 11
                            selectByMouse: true
                            onTextChanged: root.filterText = text
                            onAccepted: {
                                if (root.processedChapters.length > 0)
                                    root.chapterSelected(root.processedChapters[0])
                            }
                        }
                    }

                    Text {
                        visible: service.isFetchingChapters && root.processedChapters.length > 0
                        text: service.chaptersProgress > 0
                            ? "LOADING " + service.chaptersProgress
                            : "LOADING"
                        color: root.style.inkSoft
                        font.family: root.style.font
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        Layout.alignment: Qt.AlignVCenter
                    }

                    DetailButton {
                        visible: !service.chaptersLoaded
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 36
                        label: service.isFetchingChapters ? "Loading" : "Load"
                        icon: "download"
                        enabled: !service.isFetchingChapters
                        onClicked: service.fetchChapters()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

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
                            radius: 3
                        }
                        ScrollBar.vertical: ScrollBar {}

                        delegate: Rectangle {
                            id: chapterDelegate

                            required property var modelData
                            required property int index

                            width: chapterList.width
                            height: 52
                            color: lastRead ? root.style.selected : index % 2 === 0 ? root.style.card : root.style.paper
                            border.color: root.style.lineFaint
                            border.width: 1
                            radius: 2

                            readonly property var libraryEntry: manga ? service.getLibraryEntry(manga.id) : null
                            readonly property bool lastRead: libraryEntry
                                && libraryEntry.lastReadChapterId === modelData.id

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                spacing: 10

                                Text {
                                    Layout.preferredWidth: 58
                                    text: "CH." + root.chapterLabel(modelData.chapter)
                                    color: chapterDelegate.lastRead ? root.style.accent : root.style.inkSoft
                                    font.family: root.style.font
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: modelData.title || ("Chapter " + root.chapterLabel(modelData.chapter))
                                        color: root.style.inkStrong
                                        font.family: root.style.font
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: "No group"
                                        color: root.style.inkSoft
                                        font.family: root.style.font
                                        font.pixelSize: 9
                                        font.italic: true
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 92
                                    text: root.chapterDate(modelData)
                                    color: root.style.inkSoft
                                    font.family: root.style.font
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                }

                                MaterialSymbol {
                                    text: "chevron_right"
                                    iconSize: 18
                                    color: root.style.accent
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.chapterSelected(modelData)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: chapterDelegate.radius
                                    color: root.style.accent
                                    opacity: parent.pressed ? 0.14 : parent.containsMouse ? 0.06 : 0
                                }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: service.isFetchingChapters && root.processedChapters.length === 0

                        MaterialLoadingIndicator {
                            anchors.horizontalCenter: parent.horizontalCenter
                            loading: parent.visible
                            visible: loading
                            implicitSize: 44
                        }

                        Text {
                            text: service.chaptersProgress > 0
                                ? "LOADING CHAPTERS " + service.chaptersProgress
                                : "LOADING CHAPTERS"
                            color: root.style.inkSoft
                            font.family: root.style.font
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 520)
                        visible: !service.isFetchingChapters
                            && root.processedChapters.length === 0
                            && service.chaptersError.length === 0
                        text: service.chaptersLoaded ? "NO CHAPTERS FOUND" : "CHAPTERS ARE LOADING IN THE BACKGROUND"
                        color: root.style.inkSoft
                        font.family: root.style.font
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: service.isFetchingDetail

        MaterialLoadingIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            loading: parent.visible
            visible: loading
            implicitSize: 44
        }

        Text {
            text: "FETCHING MANGA"
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
        visible: (service.detailError.length > 0 || service.chaptersError.length > 0)
            && !service.isFetchingDetail
            && root.processedChapters.length === 0

        Text {
            width: parent.width
            text: service.detailError.length > 0 ? service.detailError : service.chaptersError
            color: root.style.accent
            font.family: root.style.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        DetailButton {
            anchors.horizontalCenter: parent.horizontalCenter
            label: "Retry"
            icon: "refresh"
            onClicked: service.retryDetail()
        }
    }
}
