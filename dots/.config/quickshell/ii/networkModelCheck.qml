import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root

    property int scans: 0

    function verifyOrder() {
        const networks = Network.friendlyWifiNetworks;
        for (let index = 1; index < networks.length; index++) {
            const previous = networks[index - 1];
            const current = networks[index];
            if (String(previous?.ssid ?? "").localeCompare(String(current?.ssid ?? "")) > 0) Qt.exit(2);
        }
    }

    Component.onCompleted: Network.acquireWifiScanner()
    Component.onDestruction: Network.releaseWifiScanner()

    Connections {
        target: Network
        function onFriendlyWifiNetworksChanged() { root.verifyOrder(); }
    }

    ListView {
        width: 1
        height: 100
        model: ScriptModel { values: Network.friendlyWifiNetworks }
        delegate: Item {
            required property var modelData
            width: 1
            height: 1
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (++root.scans <= 4) {
                Network.requestWifiScan();
                return;
            }
            root.verifyOrder();
            console.log("[NetworkModelCheck] networks=" + Network.friendlyWifiNetworks.length);
            Qt.quit();
        }
    }
}
