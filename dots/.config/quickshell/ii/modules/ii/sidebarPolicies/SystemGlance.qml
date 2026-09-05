import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: glanceRoot

    readonly property real dayProgress: {
        const date = DateTime.clock.date
        return (date.getHours() * 3600 + date.getMinutes() * 60 + date.getSeconds()) / 86400
    }
    readonly property var upcomingForecast: getUpcomingForecast(Weather.hourlyForecast)
    readonly property bool externalPower: Battery.isCharging || Battery.chargeState == 4
    property bool trackingResources: false
    property string gpuBusyPath: ""
    property real gpuUsage: 0
    property bool launcherMode: false

    function getUpcomingForecast(data) {
        if (!Array.isArray(data)) return []
        const currentSlot = Math.floor(DateTime.clock.date.getHours() / 3) * 3
        let nextDay = false
        const result = []

        for (let i = 0; i < data.length && result.length < 5; i++) {
            const hour = Math.floor(parseInt(data[i].time) / 100)
            if (i > 0 && hour < Math.floor(parseInt(data[i - 1].time) / 100))
                nextDay = true
            if (nextDay || hour >= currentSlot)
                result.push(data[i])
        }
        return result
    }

    function formatHour(time) {
        return Math.floor(parseInt(time) / 100).toString().padStart(2, "0") + ":00"
    }

    function formatGB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function formatBatteryTime(seconds) {
        if (seconds <= 0) return Translation.tr("Estimating")
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`
    }

    function updateResourceTracking() {
        const shouldTrack = glanceRoot.visible && (launcherMode ? GlobalStates.overviewOpen : GlobalStates.sidebarLeftOpen)
        if (shouldTrack === glanceRoot.trackingResources) return
        glanceRoot.trackingResources = shouldTrack
        ResourceUsage.activeInstances += shouldTrack ? 1 : -1
        if (shouldTrack) ResourceUsage.refreshDiskUsage()
    }

    Component.onCompleted: updateResourceTracking()
    Component.onDestruction: {
        if (glanceRoot.trackingResources)
            ResourceUsage.activeInstances = Math.max(0, ResourceUsage.activeInstances - 1)
    }
    onVisibleChanged: updateResourceTracking()

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() { glanceRoot.updateResourceTracking() }
        function onOverviewOpenChanged() { glanceRoot.updateResourceTracking() }
    }

    Process {
        running: true
        command: ["bash", "-c", "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && { echo \"$f\"; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!glanceRoot || !text) return
                glanceRoot.gpuBusyPath = text.trim()
                if (glanceRoot.gpuBusyPath !== "") gpuUsageFile.reload()
            }
        }
    }

    FileView {
        id: gpuUsageFile
        path: glanceRoot.gpuBusyPath
        printErrors: false
        onLoaded: {
            const content = text()
            if (!content || !glanceRoot) return
            const parsed = Number(content.trim())
            if (!Number.isFinite(parsed)) return
            glanceRoot.gpuUsage = Math.max(0, Math.min(100, parsed))
        }
    }

    Timer {
        running: glanceRoot.trackingResources && glanceRoot.gpuBusyPath !== ""
        repeat: true
        interval: 1000
        onTriggered: gpuUsageFile.reload()
    }

    GridLayout {
        anchors {
            fill: parent
            margins: 4
        }
        columns: glanceRoot.launcherMode ? 2 : 1
        rowSpacing: 10
        columnSpacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: glanceRoot.launcherMode ? 112 : 142
            radius: glanceRoot.launcherMode ? 28 : Appearance.rounding.normal
            color: Appearance.colors.colPrimaryContainer

            RowLayout {
                anchors {
                    fill: parent
                    margins: glanceRoot.launcherMode ? 12 : 18
                }
                spacing: 18

                Item {
                    Layout.preferredWidth: glanceRoot.launcherMode ? 64 : 104
                    Layout.preferredHeight: glanceRoot.launcherMode ? 64 : 104

                    CircularProgress {
                        anchors.centerIn: parent
                        implicitSize: glanceRoot.launcherMode ? 64 : 104
                        lineWidth: 7
                        gapAngle: 7
                        value: glanceRoot.dayProgress
                        colPrimary: Appearance.colors.colPrimary
                        colSecondary: Appearance.colors.colSurfaceContainerHighest
                    }

                    MaterialShape {
                        anchors.centerIn: parent
                        implicitSize: glanceRoot.launcherMode ? 42 : 72
                        shapeString: "Cookie9Sided"
                        color: Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "schedule"
                            iconSize: glanceRoot.launcherMode ? 24 : Appearance.font.pixelSize.hugeass
                            color: Appearance.colors.colOnPrimary
                            fill: 1
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    StyledText {
                        text: DateTime.time
                        font.family: Appearance.font.family.title
                        font.pixelSize: glanceRoot.launcherMode ? 38 : Appearance.font.pixelSize.hugeass * 2
                        font.weight: Font.Black
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.locale().toString(DateTime.clock.date, "dddd, dd MMMM")
                        elide: Text.ElideRight
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    RowLayout {
                        visible: !glanceRoot.launcherMode
                        Layout.fillWidth: true
                        spacing: 5

                        InfoPill {
                            Layout.fillWidth: true
                            icon: "hourglass_top"
                            text: Translation.tr("%1% today").arg(Math.floor(glanceRoot.dayProgress * 100))
                        }

                        InfoPill {
                            icon: "wb_twilight"
                            text: Weather.data.sunrise || "--"
                        }

                        InfoPill {
                            icon: "bedtime"
                            text: Weather.data.sunset || "--"
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: glanceRoot.launcherMode ? 112 : 138
            radius: glanceRoot.launcherMode ? 28 : Appearance.rounding.normal
            color: Appearance.colors.colSecondaryContainer

            RowLayout {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 10

                ColumnLayout {
                    Layout.preferredWidth: 126
                    Layout.minimumWidth: 126
                    Layout.maximumWidth: 126
                    Layout.fillHeight: true
                    spacing: 4

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        MaterialShape {
                            implicitSize: glanceRoot.launcherMode ? 36 : 58
                            shapeString: Weather.data.wCode == 113 ? "Sunny" : "Puffy"
                            color: Appearance.colors.colSecondary

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                                iconSize: glanceRoot.launcherMode ? 24 : Appearance.font.pixelSize.hugeass
                                color: Appearance.colors.colOnSecondary
                                fill: 1
                            }
                        }

                        StyledText {
                            text: Weather.data.temp || "--°"
                            font.family: Appearance.font.family.title
                            font.pixelSize: Appearance.font.pixelSize.hugeass + 8
                            font.weight: Font.Black
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike || "--°")
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHigh

                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: 9
                        }
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Next hours")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnSurface
                            }

                            StyledText {
                                visible: !glanceRoot.launcherMode
                                text: Translation.tr("%1 • %2")
                                    .arg(Weather.data.wDesc || Translation.tr("Weather unavailable"))
                                    .arg(Weather.data.city || Config.options.bar.weather.city)
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }

                        Row {
                            id: forecastRow

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 2
                            readonly property int forecastCount: Math.max(1, glanceRoot.upcomingForecast.length)
                            readonly property real slotWidth: (width - spacing * (forecastCount - 1)) / forecastCount

                            Repeater {
                                model: glanceRoot.upcomingForecast

                                delegate: Item {
                                    required property var modelData
                                    width: forecastRow.slotWidth
                                    height: forecastRow.height

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 1

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: glanceRoot.formatHour(modelData.time)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnSurfaceVariant
                                        }

                                        MaterialShape {
                                            Layout.alignment: Qt.AlignHCenter
                                    implicitSize: glanceRoot.launcherMode ? 24 : 42
                                            shapeString: "Clover4Leaf"
                                            color: Appearance.colors.colSecondaryContainer

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: Icons.getWeatherIcon(modelData.code) ?? "cloud"
                                                iconSize: glanceRoot.launcherMode ? 18 : Appearance.font.pixelSize.large
                                                color: Appearance.colors.colOnSecondaryContainer
                                            }
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: `${Weather.useUSCS ? modelData.tempF : modelData.tempC}°`
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnSurface
                                        }
                                    }
                                }
                            }

                            StyledText {
                                visible: glanceRoot.upcomingForecast.length === 0
                                width: forecastRow.width
                                height: forecastRow.height
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: Weather.loading ? Translation.tr("Loading forecast…") : Translation.tr("Forecast unavailable")
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        TelemetryCard {
            Layout.fillWidth: true
            Layout.preferredHeight: glanceRoot.launcherMode ? 128 : 112
            label: glanceRoot.launcherMode ? Translation.tr("CPU") : Translation.tr("CPU performance")
            value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
            detail: `${ResourceUsage.cpuTemp} • ${ResourceUsage.cpuFreq}`
            secondaryDetail: ResourceUsage.cpuModel
            icon: "developer_board"
            accent: Appearance.colors.colPrimary
            symbolColor: Appearance.colors.colOnPrimary
            shapeString: "Clover8Leaf"
            history: ResourceUsage.cpuUsageHistory
        }

        TelemetryCard {
            Layout.fillWidth: true
            Layout.preferredHeight: glanceRoot.launcherMode ? 128 : 112
            label: glanceRoot.launcherMode ? Translation.tr("Memory") : Translation.tr("Memory utilization")
            value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`
            detail: Translation.tr("%1 of %2").arg(glanceRoot.formatGB(ResourceUsage.memoryUsed)).arg(glanceRoot.formatGB(ResourceUsage.memoryTotal))
            secondaryDetail: Translation.tr("%1 available").arg(glanceRoot.formatGB(ResourceUsage.memoryFree))
            icon: "memory"
            accent: Appearance.colors.colSecondary
            symbolColor: Appearance.colors.colOnSecondary
            shapeString: "Flower"
            history: ResourceUsage.memoryUsageHistory
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: glanceRoot.launcherMode ? 2 : 1
            Layout.minimumHeight: glanceRoot.launcherMode ? 148 : 112
            columns: glanceRoot.launcherMode ? 4 : 2
            rowSpacing: 10
            columnSpacing: 10

            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: Translation.tr("Battery")
                value: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--"
                detail: Battery.chargeState == 4
                    ? Translation.tr("Fully charged")
                    : Battery.isCharging
                        ? Translation.tr("%1 until full").arg(glanceRoot.formatBatteryTime(Battery.timeToFull))
                        : Translation.tr("%1 remaining").arg(glanceRoot.formatBatteryTime(Battery.timeToEmpty))
                secondaryDetail: Battery.health > 0
                    ? Translation.tr("Health %1%").arg(Math.round(Battery.health))
                    : Translation.tr("Health unavailable")
                icon: Battery.isCharging ? "battery_charging_full" : "battery_android_full"
                progress: Battery.available ? Battery.percentage : 0
                accent: Battery.isLowAndNotCharging ? Appearance.m3colors.m3error : Appearance.colors.colTertiary
                symbolColor: Battery.isLowAndNotCharging ? Appearance.colors.colOnError : Appearance.colors.colOnTertiary
                shapeString: Battery.isCharging ? "Flower" : "Puffy"
            }

            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: Translation.tr("Storage")
                value: `${Math.round(ResourceUsage.diskUsedPercentage * 100)}%`
                detail: Translation.tr("%1 of %2").arg(glanceRoot.formatGB(ResourceUsage.diskUsed)).arg(glanceRoot.formatGB(ResourceUsage.diskTotal))
                secondaryDetail: Translation.tr("%1 available").arg(glanceRoot.formatGB(ResourceUsage.diskTotal - ResourceUsage.diskUsed))
                icon: "hard_drive"
                progress: ResourceUsage.diskUsedPercentage
                accent: Appearance.colors.colTertiary
                symbolColor: Appearance.colors.colOnTertiary
                shapeString: "Cookie9Sided"
            }

            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: Translation.tr("GPU")
                value: glanceRoot.gpuBusyPath !== "" ? `${Math.round(glanceRoot.gpuUsage)}%` : "--"
                detail: Translation.tr("Graphics processor")
                secondaryDetail: glanceRoot.gpuBusyPath !== ""
                    ? Translation.tr("Live utilization")
                    : Translation.tr("Utilization unavailable")
                icon: "developer_board"
                progress: glanceRoot.gpuUsage / 100
                accent: Appearance.colors.colPrimary
                symbolColor: Appearance.colors.colOnPrimary
                shapeString: "Clover4Leaf"
                segments: 16
            }

            MeterCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: Translation.tr("Energy")
                value: Battery.available ? `${Math.abs(Battery.energyRate).toFixed(1)} W` : "--"
                detail: Battery.isCharging
                    ? Translation.tr("Charging input")
                    : glanceRoot.externalPower
                        ? Translation.tr("External power")
                        : Translation.tr("System consumption")
                secondaryDetail: Battery.isCharging
                    ? Translation.tr("AC → battery")
                    : glanceRoot.externalPower
                        ? Translation.tr("AC → system")
                        : Translation.tr("Battery → system")
                icon: glanceRoot.externalPower ? "electric_bolt" : "energy_savings_leaf"
                progress: Math.min(Math.abs(Battery.energyRate) / 65, 1)
                accent: glanceRoot.externalPower ? Appearance.colors.colPrimary : Appearance.colors.colTertiary
                symbolColor: glanceRoot.externalPower ? Appearance.colors.colOnPrimary : Appearance.colors.colOnTertiary
                shapeString: glanceRoot.externalPower ? "Sunny" : "SoftBurst"
                segments: 16
            }
        }
    }

    component InfoPill: Rectangle {
        id: pill

        required property string icon
        required property string text

        implicitWidth: pillContent.implicitWidth + 12
        implicitHeight: 25
        radius: Appearance.rounding.full
        color: Appearance.colors.colSurfaceContainerHighest

        RowLayout {
            id: pillContent
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                text: pill.icon
                iconSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                text: pill.text
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
        }
    }

    component TelemetryCard: Rectangle {
        id: card

        required property string label
        required property string value
        required property string detail
        required property string secondaryDetail
        required property string icon
        required property color accent
        required property color symbolColor
        required property string shapeString
        required property list<real> history

        radius: glanceRoot.launcherMode ? 24 : Appearance.rounding.normal
        color: Appearance.colors.colSurfaceContainerHigh

        RowLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 10

            ColumnLayout {
                Layout.minimumWidth: glanceRoot.launcherMode ? 108 : 126
                Layout.preferredWidth: glanceRoot.launcherMode ? 108 : 126
                Layout.maximumWidth: glanceRoot.launcherMode ? 108 : 126
                Layout.fillHeight: true
                spacing: 2

                MaterialShape {
                    implicitSize: 34
                    shapeString: card.shapeString
                    color: card.accent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: card.icon
                        iconSize: Appearance.font.pixelSize.large
                        color: card.symbolColor
                        fill: 1
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.label
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    text: card.value
                    font.family: Appearance.font.family.title
                    font.pixelSize: glanceRoot.launcherMode ? 36 : Appearance.font.pixelSize.hugeass + 2
                    font.weight: Font.Black
                    color: card.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainerHighest
                    clip: true

                    Graph {
                        anchors.fill: parent
                        values: card.history
                        points: ResourceUsage.historyLength
                        alignment: Graph.Alignment.Right
                        color: card.accent
                        fillOpacity: 0.22
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: card.detail
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: card.secondaryDetail
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }

    component MeterCard: Rectangle {
        id: card

        required property string label
        required property string value
        required property string detail
        required property string secondaryDetail
        required property string icon
        required property real progress
        required property color accent
        required property color symbolColor
        required property string shapeString
        property int segments: 12

        radius: glanceRoot.launcherMode ? 24 : Appearance.rounding.normal
        color: Appearance.colors.colSurfaceContainerHigh

        ColumnLayout {
            anchors {
                fill: parent
                margins: 11
            }
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialShape {
                    implicitSize: glanceRoot.launcherMode ? 28 : 36
                    shapeString: card.shapeString
                    color: card.accent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: card.icon
                        iconSize: Appearance.font.pixelSize.large
                        color: card.symbolColor
                        fill: 1
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.label
                    elide: Text.ElideRight
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    visible: !glanceRoot.launcherMode
                    text: card.value
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Black
                    color: card.accent
                }
            }

            StyledText {
                visible: glanceRoot.launcherMode
                Layout.fillWidth: true
                text: card.value
                font.family: Appearance.font.family.title
                font.pixelSize: 30
                font.weight: Font.Black
                color: card.accent
            }

            StyledText {
                Layout.fillWidth: true
                text: card.detail
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }

            StyledText {
                Layout.fillWidth: true
                text: card.secondaryDetail
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: card.segments

                    delegate: Rectangle {
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 9
                        radius: Appearance.rounding.full
                        color: (index + 1) / card.segments <= card.progress
                            ? card.accent
                            : Appearance.colors.colSurfaceContainerHighest

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }
                }
            }

        }
    }
}
