import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

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

        // Search + Refresh row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialTextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search extensions...")
                onTextChanged: {
                    page.searchText = text
                    Qt.callLater(() => page.filter())
                }
            }

            RippleButton {
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                enabled: !ExtensionManager.loading
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: ExtensionManager.loading ? "progress_activity" : "refresh"
                    iconSize: 20
                    color: Appearance.colors.colOnSecondaryContainer
                }
                onClicked: ExtensionManager.refreshAvailableExtensions()
                StyledToolTip { text: Translation.tr("Refresh from GitHub") }
            }
        }

        // Loading indicator
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: ExtensionManager.loading
            text: Translation.tr("Searching GitHub for extensions...")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }

        // Error message
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: ExtensionManager.error.length > 0
            text: ExtensionManager.error
            color: Appearance.colors.colError
            wrapMode: Text.Wrap
        }

        // Extension list
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.filteredExtensions

                delegate: Item {
                    required property var modelData
                    required property int index

                    readonly property var ext: modelData
                    readonly property bool isInstalled: {
                        let installed = ExtensionManager.installedExtensions
                        for (let id in installed) {
                            if (installed[id].name === ext.name || installed[id].id === ext.name) return true
                        }
                        return false
                    }
                    readonly property bool isEnabled: {
                        let installed = ExtensionManager.installedExtensions
                        for (let id in installed) {
                            if ((installed[id].name === ext.name || installed[id].id === ext.name) && installed[id].enabled) return true
                        }
                        return false
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    visible: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        border.width: isEnabled ? 1 : 0
                        border.color: isEnabled ? Appearance.colors.colPrimary : "transparent"

                        RowLayout {
                            anchors {
                                fill: parent
                                margins: 10
                            }
                            spacing: 12

                            // Avatar / cover
                            Rectangle {
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 60
                                radius: Appearance.rounding.normal
                                color: Appearance.colors.colLayer3

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "extension"
                                    iconSize: 28
                                    color: Appearance.colors.colSubtext
                                }

                                Image {
                                    anchors.fill: parent
                                    visible: ext.hasManifest && ext.manifest && ext.manifest.coverArt
                                    source: ext.hasManifest && ext.manifest && ext.manifest.coverArt
                                           ? ext.manifest.coverArt : ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }

                            // Info column
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ext.manifest && ext.manifest.name
                                          ? ext.manifest.name : ext.name
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ext.manifest && ext.manifest.description
                                          ? ext.manifest.description : ext.description
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }

                                // Tags row
                                RowLayout {
                                    spacing: 6
                                    StyledText {
                                        text: "★ " + ext.stars
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colTertiary
                                    }
                                    StyledText {
                                        visible: ext.hasManifest
                                        text: "• " + (ext.manifest ? (ext.manifest.version || "?") : "?")
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colSubtext
                                    }
                                    StyledText {
                                        visible: ext.manifestError !== null
                                        text: "• " + Translation.tr("No manifest")
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colError
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }

                            // Action buttons
                            ColumnLayout {
                                Layout.fillHeight: true
                                spacing: 4

                                RippleButton {
                                    Layout.alignment: Qt.AlignRight
                                    implicitWidth: 80
                                    implicitHeight: 28
                                    padding: 0
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: Appearance.colors.colSecondaryContainer
                                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                    contentItem: StyledText {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: Translation.tr("Info")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    onClicked: Qt.openUrlExternally(ext.htmlUrl)
                                }

                                RippleButton {
                                    Layout.alignment: Qt.AlignRight
                                    implicitWidth: 80
                                    implicitHeight: 28
                                    padding: 0
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: isInstalled ? Appearance.colors.colError : Appearance.colors.colPrimaryContainer
                                    colBackgroundHover: isInstalled ? Appearance.colors.colErrorHover : Appearance.colors.colPrimaryContainerHover
                                    contentItem: StyledText {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: isInstalled
                                              ? Translation.tr("Remove")
                                              : Translation.tr("Install")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: isInstalled
                                               ? Appearance.colors.colOnError
                                               : Appearance.colors.colOnPrimaryContainer
                                    }
                                    onClicked: {
                                        if (isInstalled) {
                                            for (let id in ExtensionManager.installedExtensions) {
                                                let e = ExtensionManager.installedExtensions[id]
                                                if (e.name === ext.name || e.id === ext.name) {
                                                    ExtensionManager.uninstallExtension(id)
                                                    break
                                                }
                                            }
                                        } else {
                                            ExtensionManager.installExtension(ext.repoUrl, ext.name, ext.defaultBranch || "main")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: page.filteredExtensions.length === 0 && !ExtensionManager.loading
                text: page.searchText.trim()
                      ? Translation.tr("No extensions match your search")
                      : Translation.tr("No extensions found. Click refresh to search GitHub.")
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }

        // ── Installed extensions section ──
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: Object.keys(ExtensionManager.installedExtensions).length > 0
            text: Translation.tr("Installed")
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer0
        }

        Repeater {
            model: {
                let list = []
                for (let id in ExtensionManager.installedExtensions) {
                    list.push(ExtensionManager.installedExtensions[id])
                }
                return list
            }
            delegate: Item {
                required property var modelData
                property var ext: modelData
                property var updateState: ExtensionManager.updateStates[ext.id] || {}
                property bool updateChecking: updateState.checking || false
                property bool updateAvailable: updateState.updateAvailable || false

                Layout.fillWidth: true
                Layout.preferredHeight: 70

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1
                    border.width: ext.enabled ? 1 : 0
                    border.color: ext.enabled ? Appearance.colors.colPrimary : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12

                        MaterialSymbol {
                            text: ext.enabled ? "check_circle" : "cancel"
                            iconSize: 22
                            color: ext.enabled ? Appearance.colors.colPrimary : Appearance.colors.colError
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: ext.name
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer0
                            }
                            RowLayout {
                                spacing: 6
                                StyledText {
                                    text: "v" + ext.version + " by " + ext.author
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    visible: ext.repoUrl && updateChecking
                                    text: Translation.tr("Checking update...")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colTertiary
                                }
                                StyledText {
                                    visible: ext.repoUrl && updateAvailable && !updateChecking
                                    text: Translation.tr("Update available!")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    visible: ext.repoUrl && !updateChecking && !updateAvailable && updateState.localHash
                                    text: Translation.tr("Up to date")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }

                        StyledSwitch {
                            checked: ext.enabled
                            onClicked: ExtensionManager.toggleExtension(ext.id, !ext.enabled)
                        }

                        RippleButton {
                            implicitWidth: 60
                            implicitHeight: 28
                            padding: 0
                            buttonRadius: Appearance.rounding.full
                            colBackground: updateAvailable ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                            colBackgroundHover: updateAvailable ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer3Hover
                            visible: ext.repoUrl && ext.repoUrl.length > 0
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: updateChecking
                                      ? "..."
                                      : (updateAvailable ? Translation.tr("Update") : Translation.tr("Check"))
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: updateAvailable
                                       ? Appearance.colors.colOnPrimaryContainer
                                       : Appearance.colors.colSubtext
                            }
                            onClicked: {
                                if (updateAvailable) {
                                    ExtensionManager.updateExtension(ext.id)
                                } else {
                                    ExtensionManager.checkUpdate(ext.id)
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: 60
                            implicitHeight: 28
                            padding: 0
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colError
                            colBackgroundHover: Appearance.colors.colErrorHover
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: Translation.tr("Remove")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnError
                            }
                            onClicked: ExtensionManager.uninstallExtension(ext.id)
                        }
                    }
                }
            }
        }
    }


}