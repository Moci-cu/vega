pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.services.network

/**
 * Network service backed by NetworkManager over DBus.
 *
 * The public API intentionally matches the previous nmcli-backed service so
 * callers in both panel families can remain unchanged.
 */
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(device => device.type === DeviceType.Wired && device.connected)
        ?? devices.find(device => device.type === DeviceType.Wired)
        ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    property bool wifiScanning: false
    readonly property bool wifiConnecting: wifiConnectTarget?.backendNetwork?.stateChanging ?? false
    property WifiAccessPoint wifiConnectTarget
    property bool scanAfterWifiEnabled: false
    property bool initialScanRequested: false
    property int wifiScannerConsumers: 0

    property var wifiNetworks: []
    readonly property WifiAccessPoint active: wifiNetworks.find(network => network?.active) ?? null
    readonly property var friendlyWifiNetworks: wifiNetworks

    readonly property bool ethernet: devices.some(device => device.type === DeviceType.Wired && device.connected)
    readonly property string wifiStatus: {
        if (!root.wifiEnabled || !root.wifiDevice)
            return "disabled";
        if (root.wifiDevice.state === ConnectionState.Connecting
                || root.wifiNetworks.some(network => network?.backendNetwork?.state === ConnectionState.Connecting))
            return "connecting";
        if (!root.wifiDevice.connected)
            return "disconnected";
        if (Networking.connectivity === NetworkConnectivity.Limited)
            return "limited";
        return "connected";
    }
    readonly property bool wifi: wifiStatus === "connected"
    readonly property string networkName: ethernet
        ? (wiredDevice?.network?.name ?? active?.ssid ?? "")
        : (active?.ssid ?? "")
    readonly property int networkStrength: active?.strength ?? 0
    readonly property string materialSymbol: root.ethernet
        ? "lan"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (
                (root.active?.strength ?? 0) > 83 ? "signal_wifi_4_bar" :
                (root.active?.strength ?? 0) > 67 ? "network_wifi" :
                (root.active?.strength ?? 0) > 50 ? "network_wifi_3_bar" :
                (root.active?.strength ?? 0) > 33 ? "network_wifi_2_bar" :
                (root.active?.strength ?? 0) > 17 ? "network_wifi_1_bar" :
                "signal_wifi_0_bar"
            )
            : (root.wifiStatus === "connecting")
                ? "signal_wifi_statusbar_not_connected"
                : (root.wifiStatus === "disconnected")
                    ? "wifi_find"
                    : (root.wifiStatus === "disabled")
                        ? "signal_wifi_off"
                        : "signal_wifi_bad"

    function enableWifi(enabled = true): void {
        if (root.wifiEnabled === enabled) {
            if (enabled && root.scanAfterWifiEnabled) root.handleWifiAvailability();
            return;
        }

        Networking.wifiEnabled = enabled;
        if (!enabled) {
            root.initialScanRequested = false;
            root.scanAfterWifiEnabled = false;
            root.stopWifiScanner();
        }
    }

    function toggleWifi(): void {
        root.enableWifi(!root.wifiEnabled);
    }

    function rescanWifi(): void {
        if (root.wifiScanning) return;
        if (!root.wifiEnabled || !root.wifiDevice) {
            root.scanAfterWifiEnabled = true;
            return;
        }

        root.scanAfterWifiEnabled = false;
        root.wifiScanning = true;
        scanIndicatorTimer.restart();
        scannerStopTimer.restart();

        if (root.wifiDevice.scannerEnabled) {
            root.wifiDevice.scannerEnabled = false;
            scannerStartTimer.restart();
        } else {
            root.wifiDevice.scannerEnabled = true;
        }
    }

    function requestWifiScan(): void {
        if (root.wifiEnabled) {
            root.rescanWifi();
            return;
        }
        root.scanAfterWifiEnabled = true;
        root.enableWifi(true);
    }

    function acquireWifiScanner(): void {
        root.wifiScannerConsumers++;
        scannerStopTimer.stop();
        if (!root.wifiEnabled || !root.wifiDevice) return;
        if (!root.wifiDevice.scannerEnabled)
            root.wifiDevice.scannerEnabled = true;
        if (!root.wifiScanning) {
            root.wifiScanning = true;
            scanIndicatorTimer.restart();
        }
    }

    function releaseWifiScanner(): void {
        root.wifiScannerConsumers = Math.max(0, root.wifiScannerConsumers - 1);
        if (root.wifiScannerConsumers === 0) scannerStopTimer.restart();
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        if (!accessPoint?.backendNetwork) return;
        accessPoint.askingPassword = false;
        accessPoint.passwordAttemptPending = false;
        root.wifiConnectTarget = accessPoint;
        accessPoint.backendNetwork.connect();
    }

    function disconnectWifiNetwork(): void {
        if (root.active?.backendNetwork)
            root.active.backendNetwork.disconnect();
    }

    function openPublicWifiPortal(): void {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]);
    }

    function changePassword(network: WifiAccessPoint, password: string, username = ""): void {
        if (!network?.backendNetwork) return;
        if (username.trim().length > 0 || !network.supportsPsk) {
            console.warn("[Network] Built-in credentials only support WPA/WPA2 PSK and SAE; 802.1X identity is unavailable:", network.ssid);
            network.askingPassword = false;
            network.passwordAttemptPending = false;
            if (root.wifiConnectTarget === network) root.wifiConnectTarget = null;
            return;
        }
        network.askingPassword = false;
        network.passwordAttemptPending = true;
        root.wifiConnectTarget = network;
        network.backendNetwork.connectWithPsk(password);
    }

    function handleConnectionFailure(accessPoint, reason): void {
        const needsPassword = accessPoint.supportsPsk
            && (reason === ConnectionFailReason.NoSecrets || accessPoint.passwordAttemptPending);
        accessPoint.passwordAttemptPending = false;
        accessPoint.askingPassword = needsPassword;
        if (!needsPassword && root.wifiConnectTarget === accessPoint)
            root.wifiConnectTarget = null;
    }

    function syncWifiNetworks(): void {
        const backendNetworks = root.wifiDevice?.networks?.values ?? [];
        const currentNetworks = root.wifiNetworks.filter(accessPoint => accessPoint);
        const nextNetworks = [];

        for (const backendNetwork of backendNetworks) {
            const existing = currentNetworks.find(accessPoint => accessPoint.backendNetwork === backendNetwork);
            const accessPoint = existing ?? apComp.createObject(root, {
                backendNetwork: backendNetwork,
                failureHandler: root.handleConnectionFailure
            });
            if (accessPoint) nextNetworks.push(accessPoint);
        }

        // Keep ScriptModel rows stable while signal strength changes during scans.
        nextNetworks.sort((a, b) => a.ssid.localeCompare(b.ssid) || a.securityType - b.securityType);

        for (const accessPoint of currentNetworks) {
            if (nextNetworks.includes(accessPoint)) continue;
            if (root.wifiConnectTarget === accessPoint) root.wifiConnectTarget = null;
            accessPoint.destroy();
        }

        if (nextNetworks.length === currentNetworks.length
                && nextNetworks.every((accessPoint, index) => accessPoint === currentNetworks[index]))
            return;
        root.wifiNetworks = nextNetworks;
    }

    function handleWifiAvailability(): void {
        root.syncWifiNetworks();
        if (!root.wifiEnabled || !root.wifiDevice) {
            root.initialScanRequested = false;
            root.wifiScanning = false;
            return;
        }

        if (!root.initialScanRequested || root.scanAfterWifiEnabled) {
            root.initialScanRequested = true;
            root.scanAfterWifiEnabled = false;
            Qt.callLater(root.rescanWifi);
        }
    }

    function stopWifiScanner(): void {
        scannerStartTimer.stop();
        scannerStopTimer.stop();
        scanIndicatorTimer.stop();
        root.wifiScanning = false;
        if (root.wifiDevice?.scannerEnabled)
            root.wifiDevice.scannerEnabled = false;
    }

    Component.onCompleted: root.handleWifiAvailability()

    onWifiDeviceChanged: {
        root.initialScanRequested = false;
        root.handleWifiAvailability();
    }

    Connections {
        target: Networking

        function onWifiEnabledChanged() {
            if (!Networking.wifiEnabled) root.stopWifiScanner();
            root.handleWifiAvailability();
        }
    }

    Connections {
        target: Networking.devices

        function onValuesChanged() {
            root.handleWifiAvailability();
        }
    }

    Connections {
        target: root.wifiDevice?.networks ?? null

        function onValuesChanged() {
            root.syncWifiNetworks();
        }
    }

    Connections {
        target: root.wifiConnectTarget?.backendNetwork ?? null

        function onConnectedChanged() {
            if (!root.wifiConnectTarget?.backendNetwork?.connected) return;
            root.wifiConnectTarget.passwordAttemptPending = false;
            root.wifiConnectTarget.askingPassword = false;
            root.wifiConnectTarget = null;
        }
    }

    Timer {
        id: scannerStartTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.wifiEnabled && root.wifiDevice)
                root.wifiDevice.scannerEnabled = true;
        }
    }

    Timer {
        id: scanIndicatorTimer
        interval: 2500
        repeat: false
        onTriggered: root.wifiScanning = false
    }

    Timer {
        id: scannerStopTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.wifiScannerConsumers === 0 && root.wifiDevice?.scannerEnabled)
                root.wifiDevice.scannerEnabled = false;
        }
    }

    Component {
        id: apComp

        WifiAccessPoint {}
    }
}
