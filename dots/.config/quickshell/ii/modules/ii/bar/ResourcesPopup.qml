import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    onActiveChanged: {
        if (active) ResourceUsage.refreshDiskUsage()
    }

    // Helper function to format KB to GB
    function formatGB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 12

        ExpressiveMetricCard {
            id: resourcesHero

            label: Translation.tr("CPU usage")
            value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
            supportingText: ResourceUsage.cpuModel
            detailText: ResourceUsage.cpuFreq
            detailIcon: "speed"
            badgeText: ResourceUsage.cpuTemp === "--°C"
                ? Translation.tr("Temperature unavailable")
                : Translation.tr("Temperature %1").arg(ResourceUsage.cpuTemp)
            badgeIcon: "device_thermostat"
            icon: "developer_board"
            progress: ResourceUsage.cpuUsage
            shapeString: "Clover8Leaf"
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            ExpressiveStatCard {
                Layout.fillWidth: true
                label: Translation.tr("Memory")
                value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`
                supportingText: Translation.tr("%1 of %2").arg(root.formatGB(ResourceUsage.memoryUsed)).arg(root.formatGB(ResourceUsage.memoryTotal))
                icon: "memory"
                shapeString: "Flower"
                progress: ResourceUsage.memoryUsedPercentage
                shapeColor: Appearance.colors.colSecondaryContainer
                symbolColor: Appearance.colors.colOnSecondaryContainer
                progressColor: Appearance.colors.colSecondary
            }

            ExpressiveStatCard {
                visible: Config.options.bar.tooltips.showSwap
                Layout.fillWidth: true
                label: Translation.tr("Swap")
                value: `${Math.round(ResourceUsage.swapUsedPercentage * 100)}%`
                supportingText: Translation.tr("%1 of %2").arg(root.formatGB(ResourceUsage.swapUsed)).arg(root.formatGB(ResourceUsage.swapTotal))
                icon: "swap_horiz"
                shapeString: "Ghostish"
                progress: ResourceUsage.swapUsedPercentage
                shapeColor: Appearance.colors.colPrimaryContainer
                symbolColor: Appearance.colors.colOnPrimaryContainer
                progressColor: Appearance.colors.colPrimary
            }

            ExpressiveStatCard {
                Layout.fillWidth: true
                Layout.columnSpan: Config.options.bar.tooltips.showSwap ? 2 : 1
                label: Translation.tr("Storage")
                value: `${Math.round(ResourceUsage.diskUsedPercentage * 100)}%`
                supportingText: Translation.tr("%1 of %2").arg(root.formatGB(ResourceUsage.diskUsed)).arg(root.formatGB(ResourceUsage.diskTotal))
                icon: "hard_drive"
                shapeString: "Cookie9Sided"
                progress: ResourceUsage.diskUsedPercentage
                shapeColor: Appearance.colors.colTertiaryContainer
                symbolColor: Appearance.colors.colOnTertiaryContainer
                progressColor: Appearance.colors.colTertiary
            }
        }
    }
}
