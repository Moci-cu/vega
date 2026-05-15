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
        let list = ExtensionManager.availableExtensions
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 2

            ToolbarTextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search extensions...")
                
                background: Rectangle {
                    color: Appearance.colors.colLayer1
                    topLeftRadius: Appearance.rounding.full
                    bottomLeftRadius: Appearance.rounding.full
                    topRightRadius: Appearance.rounding.verysmall
                    bottomRightRadius: Appearance.rounding.verysmall
                }
                

                onTextChanged: {
                    page.searchText = text
                    Qt.callLater(() => page.filter())
                }
            }

            RippleButton {
                implicitWidth: 50
                implicitHeight: 50

                topLeftRadius: Appearance.rounding.verysmall
                topRightRadius: Appearance.rounding.full
                bottomLeftRadius: Appearance.rounding.verysmall
                bottomRightRadius: Appearance.rounding.full

                enabled: !ExtensionManager.loading
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colOnSecondary
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: ExtensionManager.loading ? "progress_activity" : "refresh"
                    iconSize: 20
                    color: Appearance.colors.colOnSecondaryContainer
                }
                onClicked: ExtensionManager.refreshAvailableExtensions()
                StyledToolTip { text: Translation.tr("Refresh from GitHub") }
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

        Item {
            Layout.preferredHeight: 10
        }

        ExtensionList {
            model: page.filteredExtensions
            searchText: page.searchText
            loading: ExtensionManager.loading
        }

        InstalledExtensionList {}
    }
}
