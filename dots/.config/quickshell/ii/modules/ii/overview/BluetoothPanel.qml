pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property string filterText: ""
    property bool startedDiscovery: false
    property string selectedAddress: ""
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: adapter?.enabled ?? false
    readonly property bool adapterBusy: adapter?.state === BluetoothAdapterState.Enabling
        || adapter?.state === BluetoothAdapterState.Disabling
    readonly property var filteredDevices: {
        if (!root.bluetoothEnabled)
            return [];
        const needle = root.filterText.trim().toLowerCase();
        return BluetoothStatus.friendlyDeviceList.filter(device => {
            const label = root.deviceLabel(device).toLowerCase();
            return needle.length === 0 || label.includes(needle)
                || String(device.address ?? "").toLowerCase().includes(needle);
        });
    }
    readonly property int deviceCount: filteredDevices.length
    readonly property int currentIndex: deviceList.currentIndex
    readonly property var selectedDevice: filteredDevices.find(
        device => device.address === root.selectedAddress)
        ?? (deviceList.currentIndex >= 0 ? filteredDevices[deviceList.currentIndex] : null)
    readonly property bool selectedBusy: selectedDevice?.pairing
        || selectedDevice?.state === BluetoothDeviceState.Connecting
        || selectedDevice?.state === BluetoothDeviceState.Disconnecting
    readonly property var selectedAction: selectedDevice && !selectedBusy ? ({
        key: `bluetooth-device:${selectedDevice.address}`,
        name: root.primaryActionText(selectedDevice),
        keepLauncherOpen: true,
        execute: () => root.toggleSelectedDevice()
    }) : null

    function deviceLabel(device) {
        return device?.name || device?.deviceName || device?.address
            || Translation.tr("Unknown device");
    }

    function deviceStatus(device) {
        if (!device) return "";
        if (device.pairing) return Translation.tr("Pairing…");
        if (device.state === BluetoothDeviceState.Connecting)
            return Translation.tr("Connecting…");
        if (device.state === BluetoothDeviceState.Disconnecting)
            return Translation.tr("Disconnecting…");
        if (device.connected) return Translation.tr("Connected");
        if (device.paired) return Translation.tr("Paired");
        return Translation.tr("Nearby");
    }

    function primaryActionText(device) {
        if (device?.connected) return Translation.tr("Disconnect");
        return device?.paired ? Translation.tr("Connect") : Translation.tr("Pair");
    }

    function moveSelection(delta) {
        if (deviceList.count <= 0) return;
        deviceList.currentIndex = Math.max(0,
            Math.min(deviceList.count - 1, Math.max(0, deviceList.currentIndex) + delta));
        deviceList.positionViewAtIndex(deviceList.currentIndex, ListView.Contain);
    }

    function toggleSelectedDevice() {
        const device = root.selectedDevice;
        if (!device || root.selectedBusy) return;
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            device.pair();
        }
    }

    function startDiscovery() {
        if (root.startedDiscovery || !root.adapter?.enabled || root.adapter.discovering) return;
        root.startedDiscovery = true;
        root.adapter.discovering = true;
    }

    function stopDiscovery() {
        if (root.startedDiscovery && root.adapter?.discovering)
            root.adapter.discovering = false;
        root.startedDiscovery = false;
    }

    function toggleAdapter() {
        if (!root.adapter || root.adapterBusy) return;
        if (root.adapter.enabled)
            root.stopDiscovery();
        root.adapter.enabled = !root.adapter.enabled;
    }

    Component.onCompleted: root.startDiscovery()
    Component.onDestruction: root.stopDiscovery()
    onAdapterChanged: Qt.callLater(root.startDiscovery)
    onFilteredDevicesChanged: {
        Qt.callLater(() => {
            if (deviceList.count <= 0) {
                deviceList.currentIndex = -1;
                return;
            }
            const retainedIndex = root.filteredDevices.findIndex(
                device => device.address === root.selectedAddress);
            deviceList.currentIndex = retainedIndex >= 0 ? retainedIndex : 0;
        });
    }

    Connections {
        target: root.adapter
        ignoreUnknownSignals: true

        function onEnabledChanged() {
            if (root.adapter?.enabled)
                Qt.callLater(root.startDiscovery);
        }
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
            id: deviceColumn

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 300

            RowLayout {
                id: deviceHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                height: 42
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Devices (%1)").arg(root.deviceCount)
                    color: Qt.rgba(1, 1, 1, 0.58)
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            ListView {
                id: deviceList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: deviceHeader.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                clip: true
                spacing: 3
                model: root.filteredDevices
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                currentIndex: count > 0 ? 0 : -1

                onCurrentIndexChanged: {
                    const device = root.filteredDevices[currentIndex];
                    if (device)
                        root.selectedAddress = device.address;
                }

                delegate: Rectangle {
                    id: deviceItem

                    required property int index
                    required property var modelData
                    readonly property bool current: deviceList.currentIndex === index
                    width: ListView.view.width
                    height: 52
                    radius: 15
                    color: current ? Qt.rgba(0.62, 0.78, 0.9, 0.16)
                        : deviceHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler { id: deviceHover }
                    TapHandler { onTapped: deviceList.currentIndex = deviceItem.index }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 11
                            color: deviceItem.modelData.connected
                                ? Qt.rgba(0.42, 0.72, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 0.7
                            border.color: Qt.rgba(1, 1, 1, deviceItem.modelData.connected ? 0.2 : 0.1)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: Icons.getBluetoothDeviceMaterialSymbol(deviceItem.modelData.icon || "")
                                iconSize: 20
                                color: deviceItem.modelData.connected
                                    ? Qt.rgba(0.72, 0.88, 1, 0.96) : Qt.rgba(1, 1, 1, 0.76)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: root.deviceLabel(deviceItem.modelData)
                                textFormat: Text.PlainText
                                color: Qt.rgba(1, 1, 1, 0.9)
                                font.pixelSize: Appearance.font.pixelSize.normal
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.deviceStatus(deviceItem.modelData)
                                    + (deviceItem.modelData.batteryAvailable
                                        ? ` · ${Math.round(deviceItem.modelData.battery * 100)}%` : "")
                                color: deviceItem.modelData.connected
                                    ? Qt.rgba(0.64, 0.84, 1, 0.78) : Qt.rgba(1, 1, 1, 0.46)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                        }

                        MaterialLoadingIndicator {
                            visible: deviceItem.modelData.pairing
                                || deviceItem.modelData.state === BluetoothDeviceState.Connecting
                                || deviceItem.modelData.state === BluetoothDeviceState.Disconnecting
                            loading: visible
                            implicitSize: 17
                            color: "transparent"
                            shapeColor: Qt.rgba(1, 1, 1, 0.65)
                        }

                        MaterialSymbol {
                            visible: !deviceItem.modelData.pairing
                                && deviceItem.modelData.state !== BluetoothDeviceState.Connecting
                                && deviceItem.modelData.state !== BluetoothDeviceState.Disconnecting
                            text: deviceItem.modelData.connected ? "check_circle" : "chevron_right"
                            iconSize: deviceItem.modelData.connected ? 18 : 20
                            color: deviceItem.modelData.connected
                                ? Qt.rgba(0.62, 0.88, 0.66, 0.9) : Qt.rgba(1, 1, 1, 0.38)
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.left: deviceColumn.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        Item {
            anchors.left: deviceColumn.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            ColumnLayout {
                visible: root.selectedDevice !== null
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 18
                anchors.bottomMargin: 16
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 68
                        radius: 22
                        color: Qt.rgba(0.56, 0.74, 0.92, 0.12)
                        border.width: 0.8
                        border.color: Qt.rgba(0.82, 0.92, 1, 0.18)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: Icons.getBluetoothDeviceMaterialSymbol(root.selectedDevice?.icon || "")
                            iconSize: 36
                            color: Qt.rgba(0.82, 0.91, 1, 0.9)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: root.deviceLabel(root.selectedDevice)
                            textFormat: Text.PlainText
                            color: Qt.rgba(1, 1, 1, 0.94)
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: detailStatus.implicitWidth + 18
                            Layout.preferredHeight: 26
                            radius: 13
                            color: root.selectedDevice?.connected
                                ? Qt.rgba(0.38, 0.72, 0.94, 0.15) : Qt.rgba(1, 1, 1, 0.07)

                            StyledText {
                                id: detailStatus

                                anchors.centerIn: parent
                                text: root.deviceStatus(root.selectedDevice)
                                color: root.selectedDevice?.connected
                                    ? Qt.rgba(0.7, 0.88, 1, 0.9) : Qt.rgba(1, 1, 1, 0.58)
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    Layout.preferredHeight: 64
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.055)
                    border.width: 0.7
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                text: Translation.tr("Device address")
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                text: root.selectedDevice?.address ?? "—"
                                color: Qt.rgba(1, 1, 1, 0.78)
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }

                        ColumnLayout {
                            visible: root.selectedDevice?.batteryAvailable ?? false
                            spacing: 1

                            StyledText {
                                Layout.alignment: Qt.AlignRight
                                text: Translation.tr("Battery")
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignRight
                                text: `${Math.round((root.selectedDevice?.battery ?? 0) * 100)}%`
                                color: Qt.rgba(0.68, 0.88, 0.7, 0.88)
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        visible: root.selectedDevice?.paired ?? false
                        implicitWidth: 108
                        implicitHeight: 34
                        enabled: !root.selectedBusy
                        buttonRadius: 17
                        colBackground: Qt.rgba(0.96, 0.35, 0.35, 0.1)
                        colBackgroundHover: Qt.rgba(0.96, 0.35, 0.35, 0.18)
                        onClicked: root.selectedDevice?.forget()

                        contentItem: StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Forget")
                            color: Qt.rgba(1, 0.66, 0.66, 0.88)
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    RippleButton {
                        implicitWidth: 108
                        implicitHeight: 34
                        enabled: !root.selectedBusy
                        buttonRadius: 17
                        colBackground: Qt.rgba(0.42, 0.72, 0.96, 0.2)
                        colBackgroundHover: Qt.rgba(0.42, 0.72, 0.96, 0.28)
                        onClicked: root.toggleSelectedDevice()

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialLoadingIndicator {
                                    visible: root.selectedBusy
                                    loading: visible
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 17
                                    color: "transparent"
                                    shapeColor: Qt.rgba(1, 1, 1, 0.82)
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.selectedBusy ? root.deviceStatus(root.selectedDevice)
                                        : root.primaryActionText(root.selectedDevice)
                                    color: Qt.rgba(0.86, 0.94, 1, 0.92)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                            }
                        }
                    }

                }
            }

            ColumnLayout {
                visible: root.selectedDevice === null
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 340)
                spacing: 10

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: !BluetoothStatus.available ? "bluetooth_disabled"
                        : root.bluetoothEnabled ? "bluetooth_searching" : "bluetooth_disabled"
                    iconSize: 42
                    color: Qt.rgba(0.76, 0.86, 0.96, 0.68)
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: !BluetoothStatus.available ? Translation.tr("No Bluetooth adapter found")
                        : !root.bluetoothEnabled ? Translation.tr("Bluetooth is off")
                        : root.adapter?.discovering ? Translation.tr("Looking for nearby devices…")
                        : Translation.tr("No Bluetooth devices found")
                    color: Qt.rgba(1, 1, 1, 0.6)
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
            anchors.rightMargin: 20
            spacing: 8

            MaterialLoadingIndicator {
                visible: root.adapterBusy || (root.adapter?.discovering ?? false)
                loading: visible
                implicitSize: 18
                color: "transparent"
                shapeColor: Qt.rgba(1, 1, 1, 0.65)
            }

            MaterialSymbol {
                visible: !root.adapterBusy && !(root.adapter?.discovering ?? false)
                text: root.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
                iconSize: 19
                color: Qt.rgba(1, 1, 1, 0.65)
            }

            StyledText {
                Layout.fillWidth: true
                text: root.adapterBusy ? Translation.tr("Updating Bluetooth…")
                    : root.adapter?.discovering ? Translation.tr("Discovering nearby devices…")
                    : root.bluetoothEnabled ? Translation.tr("Bluetooth is on")
                    : Translation.tr("Bluetooth is off")
                color: Qt.rgba(1, 1, 1, 0.54)
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            StyledSwitch {
                scale: 0.9
                enabled: BluetoothStatus.available && !root.adapterBusy
                checked: root.bluetoothEnabled
                onClicked: root.toggleAdapter()
            }
        }
    }
}
