//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env II_SETTINGS_PROCESS=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

ApplicationWindow {
    id: root
    property string firstRunFilePath: CF.FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false

    property int currentPage: 0
    property real scrollPos: 0
    property string lastSearch: ""
    property int lastSearchIndex: -1
    property int resultsCount: 0
    property string pendingSearch: ""
    property bool firstFramePresented: false
    property bool firstPageLoadScheduled: false
    property bool startupGeometryLocked: true

    function runSettingsSearch(searchText) {
        const query = searchText.trim()
        if (query === "") {
            root.pendingSearch = ""
            return
        }

        root.pendingSearch = query
        if (!searchControllerLoader.active) {
            searchControllerLoader.active = true
            return
        }
        if (searchControllerLoader.item) searchControllerLoader.item.search(query)
    }

    function applySettingsSearchResults(searchText, results) {
        if (root.pendingSearch !== searchText) return

        root.pendingSearch = ""
        if (results.length === 0) {
            noMoreResultsAnim.restart()
            return
        }

        if (root.lastSearch !== searchText) {
            root.lastSearchIndex = 0
            root.lastSearch = searchText
        } else {
            root.lastSearchIndex++
            if (results.length === 1) noMoreResultsAnim.restart()
        }

        const index = root.lastSearchIndex % results.length
        const result = results[index]
        root.resultsCount = results.length
        root.currentPage = result.pageIndex
        searchControllerLoader.item.setCurrentSearch(result.matchedString)
    }

    property var pages: [
        {
            id: "quick",
            name: Translation.tr("Quick"),
            icon: "instant_mix",
            component: "modules/settings/QuickConfig.qml"
        },
        {
            id: "general",
            name: Translation.tr("General"),
            icon: "browse",
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            id: "wifi",
            name: Translation.tr("Wi-Fi"),
            icon: "wifi",
            component: "modules/settings/WifiConfig.qml"
        },
        {
            id: "bar",
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            component: "modules/settings/BarConfig.qml"
        },
        {
            id: "background",
            name: Translation.tr("Background"),
            icon: "texture",
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            id: "interface",
            name: Translation.tr("Interface"),
            icon: "bottom_app_bar",
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            id: "services",
            name: Translation.tr("Services"),
            icon: "api",
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            id: "extensions",
            name: Translation.tr("Extensions"),
            icon: "extension",
            component: "modules/settings/ExtensionsConfig.qml"
        },
        {
            id: "advanced",
            name: Translation.tr("Advanced"),
            icon: "construction",
            component: "modules/settings/AdvancedConfig.qml"
        },
        {
            id: "about",
            name: Translation.tr("About"),
            icon: "info",
            component: "modules/settings/About.qml"
        }
    ]
    

    visible: false
    onWidthChanged: {
        if (root.visible && root.startupGeometryLocked && Math.round(root.width) !== 1100) root.width = 1100
    }
    onHeightChanged: {
        if (root.visible && root.startupGeometryLocked && Math.round(root.height) !== 750) root.height = 750
    }
    onClosing: Qt.quit()
    onFrameSwapped: {
        if (root.firstFramePresented || root.firstPageLoadScheduled) return
        root.firstPageLoadScheduled = true
        Qt.callLater(() => root.firstFramePresented = true)
    }
    title: "illogical-impulse Settings"
    
    Component.onCompleted: {
        const initialPage = (Quickshell.env("II_SETTINGS_PAGE") || "").trim().toLowerCase()
        if (initialPage.length > 0) {
            const index = root.pages.findIndex(page => page.id === initialPage)
            if (index >= 0) root.currentPage = index
        }
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed
        root.width = 1100
        root.height = 750
        root.show()
    }

    IpcHandler {
        target: "settings"

        function open(pageId: string): void {
            const requestedPage = pageId.trim().toLowerCase()
            if (requestedPage.length > 0) {
                const index = root.pages.findIndex(page => page.id === requestedPage)
                if (index >= 0) root.currentPage = index
            }
            root.show()
            root.raise()
            root.requestActivate()
        }
    }

    Loader {
        id: searchControllerLoader
        active: false
        source: "modules/settings/SettingsSearchController.qml"
        onLoaded: {
            item.resultsReady.connect(root.applySettingsSearchResults)
            if (root.pendingSearch !== "") item.search(root.pendingSearch)
        }
    }

    minimumWidth: root.startupGeometryLocked ? 1100 : 750
    minimumHeight: root.startupGeometryLocked ? 750 : 500
    width: 1100
    height: 750
    color: Appearance.m3colors.m3background

    Timer {
        interval: 650
        running: root.visible && root.startupGeometryLocked
        repeat: false
        onTriggered: root.startupGeometryLocked = false
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            Layout.fillHeight: false


            StyledText {
                id: titleText
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Settings")
                Layout.leftMargin: 20
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                id: searchBox

                SequentialAnimation {
                    id: noMoreResultsAnim
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: -30; duration: 50 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: 30; duration: 50 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: -15; duration: 40 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: 15; duration: 40 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: 0; duration: 30 }
                }

                MaterialShapeWrappedMaterialSymbol {
                    iconSize: Appearance.font.pixelSize.huge
                    shape: MaterialShape.Shape.Ghostish
                    text: resultText.show ? "" : "search" 
                    animateChange: true

                    StyledText {
                        id: resultText

                        readonly property bool show: root.lastSearchIndex !== -1 && root.resultsCount > 0

                        visible: false
                        animateChange: true
                        anchors.centerIn: parent
                        text: (root.lastSearchIndex % root.resultsCount + 1) + "/" + root.resultsCount

                        onShowChanged: if (!show) resultText.visible = false
                        Timer {
                            id: showTimer
                            interval: 100
                            running: resultText.show
                            repeat: false
                            onTriggered: resultText.visible = true
                        }
                    }
                }
                ToolbarTextField { // Search box
                    id: searchInput
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    font.pixelSize: Appearance.font.pixelSize.small
                    placeholderText: Translation.tr("Search all settings..")
                    implicitWidth: Appearance.sizes.searchWidth

                    Component.onCompleted: {
                        searchInput.forceActiveFocus()
                    }

                    onTextChanged: {
                        root.lastSearchIndex = -1
                        root.resultsCount = 0
                        root.pendingSearch = ""
                    }

                    onAccepted: root.runSettingsSearch(searchInput.text)
                }
            }
            

            Item {
                Layout.fillWidth: true
            }

            RippleButton {
                buttonRadius: Appearance.rounding.full
                implicitWidth: 35
                implicitHeight: 35
                onClicked: root.close()
                Layout.rightMargin: 10
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "close"
                    iconSize: 20
                }
            }
        }

        RowLayout { // Window content with navigation rail and content pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding
            Item {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 5
                implicitWidth: navRail.expanded ? 150 : fab.baseSize
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                NavigationRail { // Window content with navigation rail and content pane
                    id: navRail
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    spacing: 10
                    expanded: root.width > 900
                    
                    NavigationRailExpandButton {
                        focus: root.visible
                    }

                    FloatingActionButton {
                        id: fab
                        property bool justCopied: false
                        iconText: justCopied ? "check" : "edit"
                        buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                        expanded: navRail.expanded
                        downAction: () => {
                            Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                        }
                        altAction: () => {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                            fab.justCopied = true;
                            revertTextTimer.restart()
                        }

                        Timer {
                            id: revertTextTimer
                            interval: 1500
                            onTriggered: {
                                fab.justCopied = false;
                            }
                        }

                        StyledToolTip {
                            text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                        }
                    }

                    NavigationRailTabArray {
                        currentIndex: root.currentPage
                        expanded: navRail.expanded
                        Repeater {
                            model: root.pages
                            NavigationRailButton {
                                required property var index
                                required property var modelData
                                toggled: root.currentPage === index
                                onPressed: root.currentPage = index;
                                expanded: navRail.expanded
                                buttonIcon: modelData.icon
                                buttonIconRotation: modelData.iconRotation || 0
                                buttonText: modelData.name
                                showToggledHighlight: false
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            Rectangle { // Content container
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.windowRounding - root.contentPadding

                Loader {
                    id: pageLoader
                    property bool initialPageLoaded: false

                    function loadInitialPage() {
                        if (!active || initialPageLoaded) return
                        source = root.pages[root.currentPage].component
                        initialPageLoaded = true
                    }

                    anchors.fill: parent
                    opacity: 1.0

                    active: Config.ready && root.firstFramePresented
                    onActiveChanged: loadInitialPage()
                    Component.onCompleted: loadInitialPage()

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            if (!pageLoader.initialPageLoaded) {
                                pageLoader.loadInitialPage()
                                return
                            }
                            switchAnim.complete();
                            switchAnim.start();
                        }
                        function onScrollPosChanged() {
                            if (root.scrollPos == -1) return
                            scrollTimer.start()
                        }
                    }

                    Timer {
                        id: scrollTimer
                        interval: 250
                        onTriggered: {
                            pageLoader.item.contentY = root.scrollPos
                            root.scrollPos = -1
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 1
                            to: 0
                            duration: 100
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        }
                        ParallelAnimation {
                            PropertyAction {
                                target: pageLoader
                                property: "source"
                                value: root.pages[root.currentPage].component
                            }
                            PropertyAction {
                                target: pageLoader
                                property: "anchors.topMargin"
                                value: 20
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: pageLoader
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                            NumberAnimation {
                                target: pageLoader
                                properties: "anchors.topMargin"
                                to: 0
                                duration: 200
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                        }
                    }
                }
            }
        }
    }
}
