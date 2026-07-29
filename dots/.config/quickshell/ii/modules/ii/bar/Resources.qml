import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    Component.onCompleted: ResourceUsage.activeInstances++
    Component.onDestruction: ResourceUsage.activeInstances = Math.max(0, ResourceUsage.activeInstances - 1)

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            shown: true
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: true
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }

        Resource {
            iconName: "device_thermostat"
            percentage: ResourceUsage.cpuTempCelsius > 0 ? Math.min(ResourceUsage.cpuTempCelsius / 100, 1) : 0
            valueText: ResourceUsage.cpuTempCelsius > 0 ? `${ResourceUsage.cpuTempCelsius}°` : "--"
            shown: true
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: 85
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: true
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

    }

    ResourcesPopup {
        hoverTarget: root
    }
}
