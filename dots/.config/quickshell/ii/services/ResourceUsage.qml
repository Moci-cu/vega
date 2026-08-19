pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real diskTotal: 1
    property real diskUsed: 0
    property real diskUsedPercentage: diskTotal > 0 ? (diskUsed / diskTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property bool usagePollingActive: false
    property bool usageSampleActive: false
    property bool usageRefreshPending: false
    property bool memorySampleReady: false
    property bool cpuSampleReady: false
    property string cpuModel: "Unknown CPU"
    property string cpuFreq: "-- MHz"
    property string cpuTemp: "--°C"
    property real cpuTempCelsius: 0
    property int activeInstances: 0
    property string cpuTempInputPath: ""

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }

    function refreshUsage() {
        if (root.usageSampleActive) {
            root.usageRefreshPending = true
            return
        }

        root.usageSampleActive = true
        root.memorySampleReady = false
        root.cpuSampleReady = false
        usageSampleWatchdog.restart()
        fileMeminfo.reload()
        fileStat.reload()
        fileCpuTemp.reload()
    }

    function parseMemoryUsage(textMeminfo) {
        memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
        memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
        swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
        swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)
    }

    function parseCpuUsage(textStat) {
        const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
        if (cpuLine) {
            const stats = cpuLine.slice(1).map(Number)
            const total = stats.reduce((a, b) => a + b, 0)
            const idle = stats[3]

            if (previousCpuStats) {
                const totalDiff = total - previousCpuStats.total
                const idleDiff = idle - previousCpuStats.idle
                cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
            }

            previousCpuStats = { total, idle }
        }
    }

    function finishUsageSample(sample) {
        if (!root.usageSampleActive) return
        if (sample === "memory") root.memorySampleReady = true
        if (sample === "cpu") root.cpuSampleReady = true
        if (!root.memorySampleReady || !root.cpuSampleReady) return

        usageSampleWatchdog.stop()
        root.updateHistories()
        root.usageSampleActive = false
        if (root.usageRefreshPending && root.activeInstances > 0) {
            root.usageRefreshPending = false
            Qt.callLater(root.refreshUsage)
        } else {
            root.usageRefreshPending = false
        }
    }

    function cleanCpuModel(model) {
        return model
            .replace(/\(.*?\)/g, "")              // (R), (TM) vs
            .replace(/with.*$/i, "")              // with Radeon...
            .replace(/@\s*[\d.]+\s*GHz/i, "")     // @ 2.60GHz
            .replace(/\b\d+-Core\b/gi, "")        // 6-Core
            .replace(/\b\d+\s*Cores?\b/gi, "")    // 6 Cores
            .replace(/\bCPU\b/gi, "")
            .replace(/\bProcessor\b/gi, "")
            .replace(/\s+/g, " ")
            .trim()
    }

    function parseCpuInfo(textCpu) {
        if (!textCpu || textCpu.length === 0) return
        if (root.cpuModel === "Unknown CPU") {
            const modelMatch = textCpu.match(/model name\s+:\s+(.*)/i)
                ?? textCpu.match(/Hardware\s+:\s+(.*)/i)
                ?? textCpu.match(/Processor\s+:\s+(.*)/i)
            if (modelMatch) root.cpuModel = root.cleanCpuModel(modelMatch[1]) || root.cpuModel
        }
        const freqMatch = textCpu.match(/cpu MHz\s+:\s+([\d.]+)/)
        if (freqMatch) root.cpuFreq = parseInt(freqMatch[1]) + " MHz"
    }

    function parseCpuMaxFreq(textFreq) {
        const khz = Number(textFreq.trim())
        if (!Number.isFinite(khz) || khz <= 0) return
        root.maxAvailableCpuString = (khz / 1000000).toFixed(1).replace(/\.0$/, "") + " GHz"
    }

    function refreshCpuInfo() {
        fileCpuInfo.reload()
    }

    function refreshDiskUsage() {
        if (!diskProc.running) diskProc.running = true
    }

    onActiveInstancesChanged: {
        if (activeInstances > 0 && !root.usagePollingActive) {
            root.usagePollingActive = true
            root.refreshUsage()
        } else if (activeInstances === 0) {
            root.usagePollingActive = false
            root.usageRefreshPending = false
            root.usageSampleActive = false
            root.memorySampleReady = false
            root.cpuSampleReady = false
            usageSampleWatchdog.stop()
            root.previousCpuStats = undefined
            root.cpuUsage = 0
        }
    }

    Timer {
        interval: Config.options?.resources?.updateInterval ?? 3000
        running: root.activeInstances > 0
        repeat: true
        onTriggered: root.refreshUsage()
    }

    Timer {
        id: usageSampleWatchdog
        interval: Math.max(5000, (Config.options?.resources?.updateInterval ?? 3000) * 2)
        repeat: false
        onTriggered: {
            if (!root.usageSampleActive) return
            console.warn("[ResourceUsage] Sample timed out")
            root.usageSampleActive = false
            root.usageRefreshPending = false
            root.memorySampleReady = false
            root.cpuSampleReady = false
        }
    }

    FileView {
        id: fileMeminfo
        path: "/proc/meminfo"
        onLoaded: {
            if (root.usageSampleActive) {
                root.parseMemoryUsage(text())
                root.finishUsageSample("memory")
            }
        }
        onLoadFailed: root.finishUsageSample("memory")
    }
    FileView {
        id: fileStat
        path: "/proc/stat"
        onLoaded: {
            if (root.usageSampleActive) {
                root.parseCpuUsage(text())
                root.finishUsageSample("cpu")
            }
        }
        onLoadFailed: root.finishUsageSample("cpu")
    }
    FileView {
        id: fileCpuInfo
        path: "/proc/cpuinfo"
        onLoaded: root.parseCpuInfo(text())
    }
    FileView {
        id: fileCpuMaxFreq
        path: "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
        printErrors: false
        onLoaded: root.parseCpuMaxFreq(text())
    }
    FileView {
        id: fileCpuTemp
        path: root.cpuTempInputPath
        printErrors: false
        onLoaded: {
            const milli = Number(text().trim())
            if (Number.isFinite(milli)) {
                root.cpuTempCelsius = Math.round(milli / 1000)
                root.cpuTemp = root.cpuTempCelsius + "°C"
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -k / | awk 'NR==2{print $2, $3}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    var parts = text.trim().split(/\s+/);
                    if (parts.length === 2) {
                        root.diskTotal = parseInt(parts[0]); // KB
                        root.diskUsed = parseInt(parts[1]);  // KB
                    }
                }
            }
        }
    }

    Process {
        id: findCpuTempPathProc
        command: ["bash", "-c", "for h in /sys/class/hwmon/hwmon*; do [ -d \"$h\" ] || continue; name=$(cat \"$h/name\" 2>/dev/null); for t in \"$h\"/temp*_input; do [ -r \"$t\" ] || continue; label=$(cat \"${t%_input}_label\" 2>/dev/null); case \"$label $name\" in *Tctl*|*Package*id*0*|*k10temp*|*coretemp*|*zenpower*) echo \"$t\"; exit 0;; esac; fallback=${fallback:-$t}; done; done; if [ -n \"$fallback\" ]; then echo \"$fallback\"; elif [ -r /sys/class/thermal/thermal_zone0/temp ]; then echo /sys/class/thermal/thermal_zone0/temp; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuTempInputPath = text.trim().split("\n")[0] ?? ""
                if (root.cpuTempInputPath.length > 0 && root.activeInstances > 0) fileCpuTemp.reload()
            }
        }
    }

    Component.onCompleted: {
        root.refreshCpuInfo()
        fileCpuMaxFreq.reload()
    }
}
