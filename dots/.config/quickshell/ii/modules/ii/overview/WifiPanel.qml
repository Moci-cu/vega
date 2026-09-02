pragma ComponentBehavior: Bound

import "../../../services/NmcliWifiParser.js" as NmcliWifiParser
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string filterText: ""
    property var networks: []
    property bool scanning: false
    property string error: ""
    property bool disconnecting: false
    readonly property var filteredNetworks: {
        const needle = root.filterText.trim().toLowerCase();
        return needle.length === 0 ? root.networks
            : root.networks.filter(network => network.ssid.toLowerCase().includes(needle));
    }
    readonly property int networkCount: filteredNetworks.length
    readonly property int currentIndex: networkList.currentIndex
    readonly property var selectedNetwork: networkList.currentIndex >= 0
        ? filteredNetworks[networkList.currentIndex] : null
    readonly property var selectedAccessPoint: root.accessPointForSsid(root.selectedNetwork?.ssid ?? "")
    readonly property var selectedProfile: NetworkProfiles.profiles.find(
        profile => profile.ssid === (root.selectedNetwork?.ssid ?? "")) ?? null
    readonly property bool selectedActive: selectedAccessPoint?.active ?? selectedNetwork?.active ?? false
    readonly property bool operationRunning: Network.wifiConnecting
        || (selectedAccessPoint?.backendNetwork?.stateChanging ?? false)
        || NetworkProfiles.operationRunning
    readonly property bool footerBusy: operationRunning || scanning
    readonly property var selectedAction: selectedAccessPoint ? ({
        key: `wifi-network:${selectedAccessPoint.ssid}`,
        name: selectedActive ? Translation.tr("Disconnect") : Translation.tr("Connect"),
        keepLauncherOpen: true,
        execute: () => root.toggleSelectedConnection()
    }) : null

    function accessPointForSsid(ssid) {
        return Network.friendlyWifiNetworks.find(accessPoint => accessPoint.ssid === ssid) ?? null;
    }

    function canConnect(accessPoint = root.selectedAccessPoint) {
        return accessPoint && (root.selectedActive || root.selectedProfile
            || !accessPoint.isSecure || accessPoint.supportsPsk);
    }

    function toggleSelectedConnection() {
        const accessPoint = root.selectedAccessPoint;
        if (!accessPoint || root.operationRunning) return;
        root.error = "";
        root.disconnecting = root.selectedActive;
        if (root.selectedActive) {
            Network.disconnectWifiNetwork();
            return;
        }
        if (root.selectedProfile) {
            NetworkProfiles.activateProfile(root.selectedProfile, (ok, result, failure) => {
                if (!ok)
                    root.error = failure?.message ?? NetworkProfiles.lastError;
            });
            return;
        }
        Network.connectToWifiNetwork(accessPoint);
    }

    function submitPassword() {
        if (!root.selectedAccessPoint || passwordInput.text.length === 0) return;
        Network.changePassword(root.selectedAccessPoint, passwordInput.text);
        passwordInput.clear();
    }

    function moveSelection(delta) {
        if (networkList.count <= 0) return;
        networkList.currentIndex = Math.max(0,
            Math.min(networkList.count - 1, Math.max(0, networkList.currentIndex) + delta));
        networkList.positionViewAtIndex(networkList.currentIndex, ListView.Contain);
    }

    function scan(rescan = true) {
        if (scanProcess.running) return;
        root.scanning = true;
        root.error = "";
        scanProcess.output = "";
        scanProcess.errorOutput = "";
        scanProcess.exec([
            "nmcli", "-t", "--escape", "yes",
            "-f", "IN-USE,SSID,SIGNAL,RATE,SECURITY,CHAN,BSSID",
            "device", "wifi", "list", "--rescan", rescan ? "yes" : "no"
        ]);
    }

    Component.onCompleted: {
        NetworkProfiles.acquireConsumer();
        Network.acquireWifiScanner();
        root.scan(false);
    }

    Component.onDestruction: {
        NetworkProfiles.releaseConsumer();
        Network.releaseWifiScanner();
    }

    onOperationRunningChanged: {
        if (!root.operationRunning)
            root.disconnecting = false;
    }

    onFilteredNetworksChanged: {
        if (networkList.count <= 0)
            networkList.currentIndex = -1;
        else if (networkList.currentIndex < 0 || networkList.currentIndex >= networkList.count)
            networkList.currentIndex = 0;
    }

    Process {
        id: scanProcess

        property string output: ""
        property string errorOutput: ""

        stdout: StdioCollector {
            onStreamFinished: scanProcess.output = text
        }
        stderr: StdioCollector {
            onStreamFinished: scanProcess.errorOutput = text.trim()
        }
        onExited: exitCode => {
            root.scanning = false;
            if (exitCode !== 0) {
                root.error = scanProcess.errorOutput || Translation.tr("Could not scan Wi-Fi networks");
                return;
            }
            root.networks = NmcliWifiParser.parse(scanProcess.output);
            if (root.networks.length === 0)
                root.error = Translation.tr("No Wi-Fi networks found");
        }
    }

    Connections {
        target: Network

        function onNetworkNameChanged() {
            connectionRefreshTimer.restart();
        }

        function onWifiConnectingChanged() {
            if (!Network.wifiConnecting)
                connectionRefreshTimer.restart();
        }
    }

    Timer {
        id: connectionRefreshTimer

        interval: 350
        onTriggered: root.scan(false)
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(0.02, 0.025, 0.035, 0.16)
    }

    Item {
        id: content

        anchors.fill: parent
        anchors.bottomMargin: footer.height

        Item {
            id: networkColumn

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 292

            StyledText {
                id: networkHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                height: 42
                verticalAlignment: Text.AlignVCenter
                text: Translation.tr("Available Networks (%1)").arg(root.networkCount)
                color: Qt.rgba(1, 1, 1, 0.58)
                font.pixelSize: Appearance.font.pixelSize.small
            }

            ListView {
                id: networkList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: networkHeader.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                clip: true
                spacing: 3
                model: root.filteredNetworks
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                currentIndex: count > 0 ? 0 : -1

                delegate: Rectangle {
                    id: networkItem

                    required property int index
                    required property var modelData
                    readonly property var accessPoint: root.accessPointForSsid(modelData.ssid)
                    readonly property bool active: accessPoint?.active ?? modelData.active
                    width: ListView.view.width
                    height: 44
                    radius: 14
                    color: networkList.currentIndex === index
                        ? Qt.rgba(1, 1, 1, 0.13)
                        : networkHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    HoverHandler { id: networkHover }
                    TapHandler { onTapped: networkList.currentIndex = networkItem.index }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialSymbol {
                            text: networkItem.active ? "check_circle" : "network_wifi"
                            iconSize: 21
                            color: networkItem.active
                                ? Qt.rgba(0.66, 0.9, 0.58, 0.95)
                                : Qt.rgba(1, 1, 1, 0.84)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: networkItem.modelData.ssid
                            color: Qt.rgba(1, 1, 1, 0.9)
                            font.pixelSize: Appearance.font.pixelSize.normal
                            elide: Text.ElideRight
                        }

                        MaterialSymbol {
                            visible: networkItem.modelData.security.length > 0
                            text: "lock"
                            iconSize: 15
                            color: Qt.rgba(1, 1, 1, 0.55)
                        }

                        StyledText {
                            text: `${networkItem.modelData.signal}%`
                            color: Qt.rgba(1, 1, 1, 0.48)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.left: networkColumn.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        Item {
            anchors.left: networkColumn.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            ColumnLayout {
                visible: root.selectedNetwork !== null
                anchors.fill: parent
                anchors.margins: 22
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    MaterialSymbol {
                        text: root.selectedActive ? "wifi" : "network_wifi"
                        iconSize: 32
                        color: Qt.rgba(1, 1, 1, 0.88)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.selectedNetwork?.ssid ?? ""
                        color: Qt.rgba(1, 1, 1, 0.94)
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.topMargin: 5
                    text: root.selectedActive
                        ? Translation.tr("Connected") : Translation.tr("Available")
                    color: root.selectedActive
                        ? Qt.rgba(0.68, 0.9, 0.6, 0.88) : Qt.rgba(1, 1, 1, 0.52)
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    visible: root.selectedAccessPoint?.askingPassword ?? false
                    spacing: 8

                    onVisibleChanged: {
                        if (visible)
                            Qt.callLater(() => passwordInput.forceActiveFocus());
                        else
                            passwordInput.clear();
                    }

                    MaterialTextField {
                        id: passwordInput

                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Password")
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        onAccepted: root.submitPassword()
                    }

                    RippleButton {
                        implicitWidth: 72
                        implicitHeight: 32
                        buttonRadius: 16
                        colBackground: Qt.rgba(1, 1, 1, 0.08)
                        colBackgroundHover: Qt.rgba(1, 1, 1, 0.14)
                        onClicked: {
                            root.selectedAccessPoint.askingPassword = false;
                            passwordInput.clear();
                        }

                        contentItem: StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Cancel")
                            color: Qt.rgba(1, 1, 1, 0.78)
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    RippleButton {
                        implicitWidth: 78
                        implicitHeight: 32
                        enabled: passwordInput.text.length > 0
                        buttonRadius: 16
                        colBackground: Qt.rgba(1, 1, 1, 0.12)
                        colBackgroundHover: Qt.rgba(1, 1, 1, 0.18)
                        onClicked: root.submitPassword()

                        contentItem: StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Connect")
                            color: Qt.rgba(1, 1, 1, 0.88)
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.12)
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 12

                    Repeater {
                        model: [
                            [Translation.tr("Signal Strength"), `${root.selectedNetwork?.signal ?? 0}%`],
                            [Translation.tr("Rate"), root.selectedNetwork?.rate ?? "—"],
                            [Translation.tr("Security"), root.selectedNetwork?.security || Translation.tr("Open")],
                            [Translation.tr("Channel"), root.selectedNetwork?.channel ?? "—"],
                            [Translation.tr("BSSID"), root.selectedNetwork?.bssid ?? "—"]
                        ]

                        delegate: RowLayout {
                            required property var modelData
                            Layout.columnSpan: 2
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData[0]
                                color: Qt.rgba(1, 1, 1, 0.54)
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }

                            StyledText {
                                text: modelData[1]
                                color: Qt.rgba(1, 1, 1, 0.82)
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: root.selectedNetwork === null
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 340)
                spacing: 10

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.scanning ? "wifi_find" : "signal_wifi_bad"
                    iconSize: 38
                    color: Qt.rgba(1, 1, 1, 0.68)
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.scanning ? Translation.tr("Scanning for Wi-Fi networks…") : root.error
                    color: Qt.rgba(1, 1, 1, 0.62)
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
            }
        }
    }

    Rectangle {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 42
        color: Qt.rgba(1, 1, 1, 0.045)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 8

            MaterialLoadingIndicator {
                visible: root.footerBusy
                loading: visible
                Layout.alignment: Qt.AlignVCenter
                implicitSize: 18
                color: "transparent"
                shapeColor: Qt.rgba(1, 1, 1, 0.65)
            }

            MaterialSymbol {
                visible: !root.footerBusy
                Layout.alignment: Qt.AlignVCenter
                text: "wifi"
                iconSize: 19
                color: Qt.rgba(1, 1, 1, 0.65)
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.operationRunning
                    ? (root.disconnecting ? Translation.tr("Disconnecting…") : Translation.tr("Connecting…"))
                    : root.scanning ? Translation.tr("Scanning…")
                    : root.error.length > 0 ? root.error : Translation.tr("Wi-Fi networks")
                color: Qt.rgba(1, 1, 1, 0.52)
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            RippleButton {
                visible: root.selectedAccessPoint !== null
                implicitWidth: connectionButtonContent.implicitWidth + 20
                implicitHeight: 30
                enabled: !root.operationRunning && root.canConnect()
                buttonRadius: 15
                colBackground: Qt.rgba(1, 1, 1, 0.09)
                colBackgroundHover: Qt.rgba(1, 1, 1, 0.15)
                onClicked: root.toggleSelectedConnection()

                contentItem: Row {
                    id: connectionButtonContent

                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selectedActive ? "link_off" : "wifi"
                        iconSize: 17
                        color: Qt.rgba(1, 1, 1, 0.82)
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selectedActive
                            ? Translation.tr("Disconnect") : Translation.tr("Connect")
                        color: Qt.rgba(1, 1, 1, 0.82)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            RippleButton {
                implicitWidth: scanButtonContent.implicitWidth + 20
                implicitHeight: 30
                enabled: !root.scanning && !root.operationRunning
                buttonRadius: 15
                colBackground: Qt.rgba(1, 1, 1, 0.09)
                colBackgroundHover: Qt.rgba(1, 1, 1, 0.15)
                onClicked: root.scan()

                contentItem: Row {
                    id: scanButtonContent

                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "refresh"
                        iconSize: 17
                        color: Qt.rgba(1, 1, 1, 0.82)
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Scan Again")
                        color: Qt.rgba(1, 1, 1, 0.82)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
