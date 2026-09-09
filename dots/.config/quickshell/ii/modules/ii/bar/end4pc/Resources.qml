import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar.end4pc as Pc
import qs.modules.common
import qs.services

Item {
    id: root
    property bool vertical: false
    implicitWidth: row.implicitWidth
    implicitHeight: vertical ? row.implicitHeight : 40
    Component.onCompleted: ResourceUsage.activeInstances++
    Component.onDestruction: ResourceUsage.activeInstances = Math.max(0, ResourceUsage.activeInstances - 1)
    GridLayout {
        id: row
        anchors.centerIn: parent
        columns: root.vertical ? 1 : -1
        rowSpacing: 6
        columnSpacing: 6
        Pc.Resource { vertical: root.vertical; iconName: "memory"; percentage: ResourceUsage.memoryUsedPercentage; warningThreshold: Config.options.bar.resources.memoryWarningThreshold }
        Pc.Resource { vertical: root.vertical; iconName: "planner_review"; percentage: ResourceUsage.cpuUsage; warningThreshold: Config.options.bar.resources.cpuWarningThreshold }
        Pc.Resource { vertical: root.vertical; iconName: "thermostat"; percentage: ResourceUsage.cpuTempCelsius / 100 }
        Pc.Resource { vertical: root.vertical; iconName: "hard_drive"; percentage: ResourceUsage.diskUsedPercentage }
        Pc.Resource { vertical: root.vertical; iconName: "swap_horiz"; percentage: ResourceUsage.swapUsedPercentage; warningThreshold: Config.options.bar.resources.swapWarningThreshold }
    }
}
