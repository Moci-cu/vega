pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    readonly property int index: 2
    property bool register: parent.register ?? false
    property var selectedProfile: null
    property var pendingDelete: null
    property bool editorOpen: false
    property string formError: ""
    forceWidth: true
    baseWidth: 760

    function securityIndex(value) {
        if (value === "wpa-psk") return 1
        if (value === "sae") return 2
        return 0
    }

    function savedProfileForSsid(ssid) {
        return NetworkProfiles.profiles.find(profile => profile.ssid === ssid) ?? null
    }

    function connectAccessPoint(accessPoint, savedProfile) {
        if (accessPoint.active) {
            Network.disconnectWifiNetwork()
            return
        }
        if (savedProfile) {
            NetworkProfiles.activateProfile(savedProfile, null)
            return
        }
        Network.connectToWifiNetwork(accessPoint)
    }

    function openAdd(ssid = "", security = "open") {
        selectedProfile = null
        profileName.text = ssid
        ssidField.text = ssid
        securityCombo.currentIndex = securityIndex(security)
        passwordField.text = ""
        autoconnectSwitch.checked = true
        hiddenSwitch.checked = false
        meteredSwitch.checked = false
        priorityField.text = "0"
        ipv4Combo.currentIndex = 0
        addressField.text = ""
        prefixField.text = "24"
        gatewayField.text = ""
        dnsField.text = ""
        formError = ""
        editorOpen = true
        Qt.callLater(() => ssidField.forceActiveFocus())
    }

    function openEdit(profile) {
        selectedProfile = profile
        profileName.text = profile.id ?? profile.ssid ?? ""
        ssidField.text = profile.ssid ?? ""
        securityCombo.currentIndex = securityIndex(profile.security)
        passwordField.text = ""
        autoconnectSwitch.checked = profile.autoconnect ?? true
        hiddenSwitch.checked = profile.hidden ?? false
        meteredSwitch.checked = profile.metered ?? false
        priorityField.text = String(profile.priority ?? 0)
        ipv4Combo.currentIndex = profile.ipv4Method === "manual" ? 1 : 0
        addressField.text = profile.address ?? ""
        prefixField.text = String(profile.prefix ?? 24)
        gatewayField.text = profile.gateway ?? ""
        dnsField.text = Array.isArray(profile.dns) ? profile.dns.join(", ") : ""
        formError = profile.security === "unsupported"
            ? Translation.tr("This profile uses security settings that are not supported in v1") : ""
        editorOpen = true
    }

    function profileParams() {
        return {
            path: selectedProfile?.path ?? "",
            uuid: selectedProfile?.uuid ?? "",
            versionId: selectedProfile?.versionId ?? "",
            name: profileName.text.trim(),
            ssid: ssidField.text.trim(),
            security: securityCombo.currentValue,
            password: passwordField.text,
            autoconnect: autoconnectSwitch.checked,
            hidden: hiddenSwitch.checked,
            metered: meteredSwitch.checked,
            priority: Number(priorityField.text || 0),
            ipv4Method: ipv4Combo.currentValue,
            address: addressField.text.trim(),
            prefix: Number(prefixField.text || 24),
            gateway: gatewayField.text.trim(),
            dns: dnsField.text.split(",").map(value => value.trim()).filter(value => value.length > 0),
            activate: true
        }
    }

    function saveProfile() {
        formError = ""
        const params = profileParams()
        if (params.ssid.length === 0) {
            formError = Translation.tr("SSID is required")
            return
        }
        if (params.security !== "open" && params.password.length < 8) {
            formError = selectedProfile
                ? Translation.tr("Re-enter the password to save changes to a secured network")
                : Translation.tr("A password of at least 8 characters is required")
            return
        }
        const done = function(ok, result, error) {
            if (!ok) {
                page.formError = error?.message ?? NetworkProfiles.lastError
                return
            }
            page.editorOpen = false
            page.selectedProfile = null
        }
        if (selectedProfile) NetworkProfiles.updateProfile(params, done)
        else NetworkProfiles.createProfile(params, done)
    }

    Component.onCompleted: {
        NetworkProfiles.acquireConsumer()
        Network.acquireWifiScanner()
    }
    Component.onDestruction: {
        NetworkProfiles.releaseConsumer()
        Network.releaseWifiScanner()
    }

    ContentSection {
        icon: "wifi"
        title: Translation.tr("Wi-Fi")
        stringMap: [Translation.tr("Wireless"), Translation.tr("Network profiles"), Translation.tr("DNS")]

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusLayout.implicitHeight + 24
            radius: 8
            color: Appearance.m3colors.m3surfaceContainer

            RowLayout {
                id: statusLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    text: Network.materialSymbol
                    iconSize: 26
                    shape: MaterialShape.Shape.Cookie4Sided
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: Network.networkName.length > 0 ? Network.networkName : Translation.tr("Not connected")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: NetworkProfiles.available
                            ? Translation.tr("NetworkManager %1").arg(NetworkProfiles.backendVersion)
                            : Translation.tr("Native profile helper unavailable")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: NetworkProfiles.available ? Appearance.colors.colSubtext : Appearance.m3colors.m3error
                    }
                }

                IconToolbarButton {
                    text: "refresh"
                    enabled: Network.wifiEnabled && !Network.wifiScanning
                    onClicked: Network.requestWifiScan()
                    StyledToolTip { text: Translation.tr("Scan for networks") }
                }

                StyledSwitch {
                    checked: Network.wifiEnabled
                    onToggled: Network.enableWifi(checked)
                }

                DialogButton {
                    visible: !NetworkProfiles.available
                    buttonText: Translation.tr("Retry")
                    onClicked: NetworkProfiles.retry()
                }

                DialogButton {
                    visible: !NetworkProfiles.available
                    buttonText: Translation.tr("External settings")
                    onClicked: Quickshell.execDetached(["bash", "-c", Config.options.apps.network])
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: NetworkProfiles.lastError.length > 0
            text: NetworkProfiles.lastError
            color: Appearance.m3colors.m3error
            wrapMode: Text.Wrap
        }
    }

    ContentSection {
        icon: "wifi_find"
        title: Translation.tr("Available networks")
        stringMap: [Translation.tr("Scan"), Translation.tr("Hidden network"), Translation.tr("Signal strength")]

        StyledIndeterminateProgressBar {
            Layout.fillWidth: true
            visible: Network.wifiScanning
        }

        Repeater {
            model: ScriptModel { values: Network.friendlyWifiNetworks }

            delegate: Rectangle {
                required property var modelData
                readonly property var savedProfile: page.savedProfileForSsid(modelData.ssid)
                Layout.fillWidth: true
                implicitHeight: availableContent.implicitHeight + 20
                radius: 8
                color: modelData.active ? Appearance.colors.colSecondaryContainer : "transparent"

                ColumnLayout {
                    id: availableContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            property int strength: modelData.strength ?? 0
                            text: strength > 80 ? "signal_wifi_4_bar"
                                : strength > 60 ? "network_wifi_3_bar"
                                : strength > 40 ? "network_wifi_2_bar"
                                : strength > 20 ? "network_wifi_1_bar" : "signal_wifi_0_bar"
                            iconSize: 23
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.ssid || Translation.tr("Unknown network")
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.active
                                    ? Translation.tr("Connected")
                                    : modelData.isSecure ? modelData.security : Translation.tr("Open network")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                        }
                        MaterialSymbol {
                            visible: modelData.isSecure
                            text: "lock"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                        }
                        DialogButton {
                            buttonText: modelData.active ? Translation.tr("Disconnect") : Translation.tr("Connect")
                            enabled: modelData.active || (!NetworkProfiles.operationRunning
                                && (savedProfile || !modelData.isSecure || modelData.supportsPsk))
                            onClicked: page.connectAccessPoint(modelData, savedProfile)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: modelData.askingPassword
                        spacing: 8
                        onVisibleChanged: {
                            if (visible) Qt.callLater(() => accessPointPassword.forceActiveFocus())
                            else accessPointPassword.clear()
                        }

                        MaterialTextField {
                            id: accessPointPassword
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Password")
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData
                            onAccepted: Network.changePassword(modelData, text)
                        }
                        DialogButton {
                            buttonText: Translation.tr("Cancel")
                            onClicked: {
                                modelData.askingPassword = false
                                accessPointPassword.clear()
                            }
                        }
                        DialogButton {
                            buttonText: Translation.tr("Connect")
                            enabled: accessPointPassword.text.length > 0
                            onClicked: Network.changePassword(modelData, accessPointPassword.text)
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "bookmark"
        title: Translation.tr("Saved networks")
        stringMap: [Translation.tr("Autoconnect"), Translation.tr("Forget network"), Translation.tr("IP address")]

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: NetworkProfiles.loading
                    ? Translation.tr("Loading profiles...")
                    : Translation.tr("%1 saved Wi-Fi profiles").arg(NetworkProfiles.profiles.length)
                color: Appearance.colors.colSubtext
            }
            DialogButton {
                buttonText: Translation.tr("Add network")
                enabled: NetworkProfiles.available && NetworkProfiles.canModify && !NetworkProfiles.operationRunning
                onClicked: page.openAdd()
            }
        }

        Repeater {
            model: ScriptModel { values: NetworkProfiles.profiles }

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: savedRow.implicitHeight + 20
                radius: 8
                color: modelData.active ? Appearance.colors.colSecondaryContainer : Appearance.m3colors.m3surfaceContainerLow

                RowLayout {
                    id: savedRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    MaterialSymbol {
                        text: modelData.active ? "wifi" : "wifi_lock"
                        iconSize: 23
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.id || modelData.ssid
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: [
                                modelData.ssid,
                                modelData.security === "open" ? Translation.tr("Open") : modelData.security,
                                modelData.autoconnect ? Translation.tr("Auto-connect") : ""
                            ].filter(value => value.length > 0).join(" | ")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                    }
                    IconToolbarButton {
                        text: modelData.active ? "link_off" : "wifi"
                        enabled: !NetworkProfiles.operationRunning
                        onClicked: {
                            if (modelData.active) Network.disconnectWifiNetwork()
                            else NetworkProfiles.activateProfile(modelData, null)
                        }
                        StyledToolTip { text: modelData.active ? Translation.tr("Disconnect") : Translation.tr("Connect") }
                    }
                    IconToolbarButton {
                        text: "edit"
                        enabled: !NetworkProfiles.operationRunning
                        onClicked: page.openEdit(modelData)
                        StyledToolTip { text: Translation.tr("Edit profile") }
                    }
                    IconToolbarButton {
                        text: "delete"
                        enabled: !NetworkProfiles.operationRunning
                        onClicked: page.pendingDelete = modelData
                        StyledToolTip { text: Translation.tr("Forget network") }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !NetworkProfiles.loading && NetworkProfiles.profiles.length === 0
            text: NetworkProfiles.available
                ? Translation.tr("No saved Wi-Fi profiles")
                : Translation.tr("Build the Vega network helper to manage saved profiles")
            color: Appearance.colors.colSubtext
        }
    }

    ContentSection {
        visible: page.editorOpen
        icon: page.selectedProfile ? "edit" : "add"
        title: page.selectedProfile ? Translation.tr("Edit Wi-Fi profile") : Translation.tr("Add Wi-Fi profile")

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            MaterialTextField {
                id: profileName
                Layout.fillWidth: true
                placeholderText: Translation.tr("Profile name")
            }
            MaterialTextField {
                id: ssidField
                Layout.fillWidth: true
                placeholderText: Translation.tr("SSID")
            }
            StyledComboBox {
                id: securityCombo
                Layout.fillWidth: true
                model: [
                    { label: Translation.tr("Open"), value: "open", icon: "" },
                    { label: Translation.tr("WPA/WPA2 Personal"), value: "wpa-psk", icon: "" },
                    { label: Translation.tr("WPA3 Personal"), value: "sae", icon: "" }
                ]
                textRole: "label"
                valueRole: "value"
            }
            MaterialTextField {
                id: passwordField
                Layout.fillWidth: true
                enabled: securityCombo.currentValue !== "open"
                placeholderText: page.selectedProfile ? Translation.tr("Re-enter password") : Translation.tr("Password")
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData
            }
            MaterialTextField {
                id: priorityField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Auto-connect priority")
                validator: IntValidator { bottom: -999; top: 999 }
            }
            StyledComboBox {
                id: ipv4Combo
                Layout.fillWidth: true
                model: [
                    { label: Translation.tr("IPv4 automatic (DHCP)"), value: "auto", icon: "" },
                    { label: Translation.tr("IPv4 manual"), value: "manual", icon: "" }
                ]
                textRole: "label"
                valueRole: "value"
            }
        }

        ConfigRow {
            uniform: true
            ConfigSwitch {
                id: autoconnectSwitch
                text: Translation.tr("Auto-connect")
                buttonIcon: "autorenew"
            }
            ConfigSwitch {
                id: hiddenSwitch
                text: Translation.tr("Hidden SSID")
                buttonIcon: "visibility_off"
            }
            ConfigSwitch {
                id: meteredSwitch
                text: Translation.tr("Metered")
                buttonIcon: "data_usage"
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: ipv4Combo.currentValue === "manual"
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            MaterialTextField {
                id: addressField
                Layout.fillWidth: true
                placeholderText: Translation.tr("IPv4 address")
            }
            MaterialTextField {
                id: prefixField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Prefix length")
                validator: IntValidator { bottom: 1; top: 32 }
            }
            MaterialTextField {
                id: gatewayField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Gateway")
            }
        }

        MaterialTextField {
            id: dnsField
            Layout.fillWidth: true
            placeholderText: Translation.tr("Custom DNS servers, comma separated (optional)")
        }

        StyledText {
            Layout.fillWidth: true
            visible: page.formError.length > 0
            text: page.formError
            color: Appearance.m3colors.m3error
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            DialogButton {
                buttonText: Translation.tr("Cancel")
                enabled: !NetworkProfiles.operationRunning
                onClicked: page.editorOpen = false
            }
            DialogButton {
                buttonText: NetworkProfiles.operationRunning ? Translation.tr("Saving...") : Translation.tr("Save and connect")
                enabled: !NetworkProfiles.operationRunning && page.selectedProfile?.security !== "unsupported"
                onClicked: page.saveProfile()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: page.pendingDelete !== null
        implicitHeight: deleteLayout.implicitHeight + 24
        radius: 8
        color: Appearance.m3colors.m3errorContainer

        RowLayout {
            id: deleteLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            MaterialSymbol {
                text: "delete_forever"
                color: Appearance.m3colors.m3onErrorContainer
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Forget %1?").arg(page.pendingDelete?.id ?? "")
                color: Appearance.m3colors.m3onErrorContainer
            }
            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: page.pendingDelete = null
            }
            DialogButton {
                buttonText: Translation.tr("Forget")
                enabled: !NetworkProfiles.operationRunning
                onClicked: {
                    const profile = page.pendingDelete
                    NetworkProfiles.deleteProfile(profile, function(ok) {
                        if (ok) page.pendingDelete = null
                    })
                }
            }
        }
    }
}
