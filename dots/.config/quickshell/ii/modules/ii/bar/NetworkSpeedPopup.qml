import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "./cards"
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    readonly property bool wifiConnected: !Network.ethernet && Network.wifiStatus === "connected"
    readonly property bool connectionWarning: !Network.ethernet
        && (Network.wifiStatus === "connecting" || Network.wifiStatus === "limited")
    readonly property bool connectionOffline: !Network.ethernet
        && (Network.wifiStatus === "disabled" || Network.wifiStatus === "disconnected")

    readonly property color heroContainerColor: connectionOffline
        ? Appearance.colors.colErrorContainer
        : connectionWarning
            ? Appearance.colors.colTertiaryContainer
            : Appearance.colors.colPrimaryContainer
    readonly property color heroAccentColor: connectionOffline
        ? Appearance.colors.colError
        : connectionWarning
            ? Appearance.colors.colTertiary
            : Appearance.colors.colPrimary
    readonly property color heroOnContainerColor: connectionOffline
        ? Appearance.colors.colOnErrorContainer
        : connectionWarning
            ? Appearance.colors.colOnTertiaryContainer
            : Appearance.colors.colOnPrimaryContainer
    readonly property color heroOnAccentColor: connectionOffline
        ? Appearance.colors.colOnError
        : connectionWarning
            ? Appearance.colors.colOnTertiary
            : Appearance.colors.colOnPrimary

    function formatSpeed(bytesPerSecond) {
        var bits = bytesPerSecond * 8;
        var suffix = "bps";

        if (bits < 1000) {
            return bits.toFixed(0) + " " + suffix;
        } else if (bits < 1000000) {
            return (bits / 1000).toFixed(1) + " K" + suffix;
        } else if (bits < 1000000000) {
            return (bits / 1000000).toFixed(1) + " M" + suffix;
        } else {
            return (bits / 1000000000).toFixed(1) + " G" + suffix;
        }
    }

    function formatTotal(bytes) {
        var bits = bytes * 8;

        if (bits < 1000000) {
            return (bits / 1000).toFixed(1) + " Kb";
        } else if (bits < 1000000000) {
            return (bits / 1000000).toFixed(1) + " Mb";
        } else {
            return (bits / 1000000000).toFixed(1) + " Gb";
        }
    }

    function connectionStatusText() {
        if (Network.ethernet)
            return Network.networkName || Translation.tr("Connected");
        if (Network.wifiStatus === "connecting")
            return Translation.tr("Connecting");
        if (Network.wifiStatus === "limited")
            return Network.networkName || Translation.tr("Limited connection");
        if (Network.wifiStatus === "disabled")
            return Translation.tr("Wi-Fi is turned off");
        if (Network.wifiStatus === "disconnected")
            return Translation.tr("Not connected");
        return Network.networkName || Translation.tr("Connected");
    }

    function connectionBadgeText() {
        if (Network.ethernet)
            return Translation.tr("Wired");
        if (root.wifiConnected)
            return Translation.tr("Signal %1%").arg(Network.networkStrength);
        if (Network.wifiStatus === "connecting")
            return Translation.tr("Connecting");
        if (Network.wifiStatus === "limited")
            return Translation.tr("Limited");
        return Translation.tr("Offline");
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        ExpressiveMetricCard {
            id: networkHero

            label: Translation.tr("Network")
            value: Network.ethernet ? Translation.tr("Ethernet") : Translation.tr("Wi-Fi")
            supportingText: root.connectionStatusText()
            badgeText: root.connectionBadgeText()
            badgeIcon: Network.ethernet ? "cable" : Network.materialSymbol
            icon: Network.materialSymbol
            progress: Network.networkStrength / 100
            showProgress: root.wifiConnected
            shapeString: Network.ethernet ? "Clover4Leaf" : "SoftBurst"

            containerColor: root.heroContainerColor
            accentColor: root.heroAccentColor
            shapeColor: root.heroAccentColor
            symbolColor: root.heroOnAccentColor
            textColor: root.heroOnContainerColor
            mutedTextColor: root.heroOnContainerColor
            badgeColor: Appearance.colors.colSurfaceContainerHighest
            badgeTextColor: Appearance.colors.colOnSurface
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ExpressiveStatCard {
                    label: Translation.tr("Download")
                    value: root.formatSpeed(NetworkUsage.networkDownloadSpeed)
                    supportingText: Translation.tr("Current speed")
                    icon: "arrow_downward"
                    shapeString: "Flower"
                    progress: -1
                    shapeColor: Appearance.colors.colPrimaryContainer
                    symbolColor: Appearance.colors.colOnPrimaryContainer
                    progressColor: Appearance.colors.colPrimary
                }

                ExpressiveStatCard {
                    label: Translation.tr("Upload")
                    value: root.formatSpeed(NetworkUsage.networkUploadSpeed)
                    supportingText: Translation.tr("Current speed")
                    icon: "arrow_upward"
                    shapeString: "PuffyDiamond"
                    progress: -1
                    shapeColor: Appearance.colors.colSecondaryContainer
                    symbolColor: Appearance.colors.colOnSecondaryContainer
                    progressColor: Appearance.colors.colSecondary
                }
            }

            ExpressiveInfoTile {
                visible: !Config.options.bar.tooltips.compactPopups
                icon: "data_usage"
                label: Translation.tr("Total transferred")
                value: root.formatTotal(NetworkUsage.networkDownloadTotal + NetworkUsage.networkUploadTotal)
                shapeString: "Cookie9Sided"
                containerColor: Appearance.colors.colTertiaryContainer
                shapeColor: Appearance.colors.colTertiary
                symbolColor: Appearance.colors.colOnTertiary
                textColor: Appearance.colors.colOnTertiaryContainer
                labelColor: Appearance.colors.colOnTertiaryContainer
            }
        }
    }
}
