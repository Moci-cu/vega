import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.settings

ContentPage {
    id: page
    readonly property int index: 8
    property bool register: parent.register ?? false
    forceWidth: true

    property string searchText: ""
    property var filteredExtensions: []
    Component.onCompleted: {
        if (!ExtensionManager.ready) return
        if (ExtensionManager.availableExtensions.length === 0) {
            ExtensionManager.refreshAvailableExtensions()
        }
        ExtensionManager.checkAllUpdates()
        page.filter()
    }

    Connections {
        target: ExtensionManager
        function onReadyChanged() { if (ExtensionManager.ready) page.filter() }
        function onExtensionSearchDone() { page.filter() }
        function onManifestReady(repoId) { page.filter() }
        function onExtensionInstalled(extId) { page.filter() }
        function onExtensionRemoved(extId) { page.filter() }
        function onExtensionToggled(extId) { page.filter() }
        function onUpdateCheckDone(extId, available, error) { page.filter() }
    }

    function filter() {
        let installed = ExtensionManager.installedExtensions
        let list = ExtensionManager.availableExtensions

        // Exclude installed extensions
        let installedIds = {}
        for (let id in installed) {
            installedIds[installed[id].name] = true
            installedIds[installed[id].id] = true
        }
        list = list.filter(e => !installedIds[e.name])

        // Filter by search text
        if (page.searchText.trim()) {
            let q = page.searchText.toLowerCase().trim()
            list = list.filter(e =>
                e.name.toLowerCase().includes(q) ||
                e.fullName.toLowerCase().includes(q) ||
                e.description.toLowerCase().includes(q)
            )
        }
        page.filteredExtensions = list
    }

    ContentSection {
        icon: "extension"
        title: Translation.tr("Extensions")

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 50
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 4
                spacing: 8

                MaterialSymbol {
                    text: "search"
                    iconSize: 20
                    color: Appearance.colors.colOnSecondaryContainer
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: Translation.tr("Search extensions...")
                    placeholderTextColor: Appearance.colors.colSubtext
                    color: Appearance.colors.colOnLayer1
                    font {
                        family: Appearance.font.family.main
                        pixelSize: Appearance.font.pixelSize.small
                        hintingPreference: Font.PreferFullHinting
                        variableAxes: Appearance.font.variableAxes.main
                    }
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.colors.colOnSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    background: null
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0

                    onTextChanged: {
                        page.searchText = text
                        Qt.callLater(() => page.filter())
                    }
                }

                RippleButton {
                    implicitWidth: 42
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.full
                    enabled: !ExtensionManager.loading
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: ExtensionManager.loading ? "progress_activity" : "refresh"
                        iconSize: 20
                        color: ExtensionManager.loading ? Appearance.colors.colSubtext : Appearance.colors.colOnSecondaryContainer
                    }
                    onClicked: ExtensionManager.refreshAvailableExtensions()
                    StyledToolTip { text: Translation.tr("Refresh from GitHub") }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: ExtensionManager.loading
            text: Translation.tr("Searching GitHub for extensions...")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: ExtensionManager.error.length > 0
            text: ExtensionManager.error
            color: Appearance.colors.colError
            wrapMode: Text.Wrap
        }

        InstalledExtensionList {}

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: page.filteredExtensions.length > 0
            text: Translation.tr("Browse Extensions")
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer0
        }

        ExtensionList {
            model: page.filteredExtensions
            searchText: page.searchText
            loading: ExtensionManager.loading
        }
    }
}
