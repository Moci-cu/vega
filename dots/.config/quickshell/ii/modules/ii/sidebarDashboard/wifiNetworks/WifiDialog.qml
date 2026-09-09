import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.functions as CF
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    property string filterText: ""
    property bool scannerAcquired: false
    readonly property var filteredWifiNetworks: {
        const query = filterText.trim().toLowerCase();
        if (query.length === 0) return Network.friendlyWifiNetworks;
        return Network.friendlyWifiNetworks.filter(network => network.ssid.toLowerCase().includes(query));
    }

    onShowChanged: {
        if (show) {
            if (!scannerAcquired) {
                scannerAcquired = true;
                Network.acquireWifiScanner();
            }
            return;
        }
        if (scannerAcquired) {
            scannerAcquired = false;
            Network.releaseWifiScanner();
        }
        networkSearchField.clear();
    }

    Component.onDestruction: {
        if (scannerAcquired) Network.releaseWifiScanner();
    }

    WindowDialogTitle {
        text: Translation.tr("Connect to Wi-Fi")
    }
    WindowDialogSeparator {
        visible: !Network.wifiScanning
    }
    StyledIndeterminateProgressBar {
        visible: Network.wifiScanning
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        Layout.maximumHeight: 40
        spacing: 8

        ToolbarTextField {
            id: networkSearchField
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: Translation.tr("Search networks")
            onTextChanged: root.filterText = text
        }

        IconToolbarButton {
            Layout.fillHeight: true
            text: "refresh"
            enabled: !Network.wifiScanning
            onClicked: Network.requestWifiScan()

            StyledToolTip {
                text: Translation.tr("Scan for networks")
            }
        }
    }

    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        ListView {
            id: wifiList
            anchors.fill: parent
            clip: true
            spacing: 0

            model: ScriptModel {
                values: root.filteredWifiNetworks
            }
            delegate: WifiNetworkItem {
                required property WifiAccessPoint modelData
                wifiNetwork: modelData
                width: ListView.view.width
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: wifiList.count === 0 && !Network.wifiScanning
            text: root.filterText.trim().length > 0 ? Translation.tr("No matching networks") : Translation.tr("No networks found")
            color: Appearance.colors.colSubtext
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached([CF.FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/scripts/launch_settings.sh`), "wifi"]);
                GlobalStates.sidebarRightOpen = false;
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
