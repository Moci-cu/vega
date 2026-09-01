pragma ComponentBehavior: Bound

import "../../../services/NmcliWifiParser.js" as NmcliWifiParser
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string filterText: ""
    property var networks: []
    property bool scanning: false
    property string error: ""
    readonly property var filteredNetworks: {
        const needle = root.filterText.trim().toLowerCase();
        return needle.length === 0 ? root.networks
            : root.networks.filter(network => network.ssid.toLowerCase().includes(needle));
    }
    readonly property int networkCount: filteredNetworks.length
    readonly property int currentIndex: networkList.currentIndex
    readonly property var selectedNetwork: networkList.currentIndex >= 0
        ? filteredNetworks[networkList.currentIndex] : null

    function moveSelection(delta) {
        if (networkList.count <= 0) return;
        networkList.currentIndex = Math.max(0,
            Math.min(networkList.count - 1, Math.max(0, networkList.currentIndex) + delta));
        networkList.positionViewAtIndex(networkList.currentIndex, ListView.Contain);
    }

    function scan() {
        if (scanProcess.running) return;
        root.scanning = true;
        root.error = "";
        scanProcess.output = "";
        scanProcess.errorOutput = "";
        scanProcess.exec([
            "nmcli", "-t", "--escape", "yes",
            "-f", "IN-USE,SSID,SIGNAL,RATE,SECURITY,CHAN,BSSID",
            "device", "wifi", "list", "--rescan", "yes"
        ]);
    }

    Component.onCompleted: root.scan()

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
                            text: networkItem.modelData.active ? "check_circle" : "network_wifi"
                            iconSize: 21
                            color: networkItem.modelData.active
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
                        text: root.selectedNetwork?.active ? "wifi" : "network_wifi"
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
                    text: root.selectedNetwork?.active
                        ? Translation.tr("Connected") : Translation.tr("Available")
                    color: root.selectedNetwork?.active
                        ? Qt.rgba(0.68, 0.9, 0.6, 0.88) : Qt.rgba(1, 1, 1, 0.52)
                    font.pixelSize: Appearance.font.pixelSize.small
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

            MaterialSymbol {
                text: "wifi"
                iconSize: 19
                color: Qt.rgba(1, 1, 1, 0.65)
            }

            StyledText {
                Layout.fillWidth: true
                text: root.scanning ? Translation.tr("Scanning…")
                    : root.error.length > 0 ? root.error : Translation.tr("Wi-Fi networks")
                color: Qt.rgba(1, 1, 1, 0.52)
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            RippleButton {
                implicitWidth: 104
                implicitHeight: 30
                enabled: !root.scanning
                buttonRadius: 15
                colBackground: Qt.rgba(1, 1, 1, 0.09)
                colBackgroundHover: Qt.rgba(1, 1, 1, 0.15)
                onClicked: root.scan()

                contentItem: RowLayout {
                    spacing: 6

                    MaterialSymbol {
                        text: "refresh"
                        iconSize: 17
                        color: Qt.rgba(1, 1, 1, 0.82)
                    }

                    StyledText {
                        text: Translation.tr("Scan Again")
                        color: Qt.rgba(1, 1, 1, 0.82)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
