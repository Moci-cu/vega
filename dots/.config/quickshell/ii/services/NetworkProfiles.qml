pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions as CF

Singleton {
    id: root

    readonly property string helperPath: CF.FileUtils.trimFileProtocol(`${Directories.home}/.local/lib/vega/vega-network-helper`)
    property var profiles: []
    property bool available: false
    property bool canModify: false
    property bool loading: false
    property bool operationRunning: false
    property string backendVersion: ""
    property string lastError: ""
    property int consumers: 0
    property int nextRequestId: 1
    property var pendingRequests: ({})

    function acquireConsumer(): void {
        consumers++
        stopTimer.stop()
        if (!helperProcess.running) start()
        else refreshProfiles()
    }

    function releaseConsumer(): void {
        consumers = Math.max(0, consumers - 1)
        if (consumers === 0) stopTimer.restart()
    }

    function start(): void {
        if (helperProcess.running) return
        lastError = ""
        helperProcess.command = [root.helperPath]
        helperProcess.running = true
    }

    function stop(): void {
        readyTimer.stop()
        lastError = Translation.tr("Wi-Fi helper stopped")
        helperProcess.running = false
        available = false
        loading = false
        operationRunning = false
        failPending(lastError)
    }

    function retry(): void {
        if (helperProcess.running) helperProcess.running = false
        retryTimer.restart()
    }

    function request(method: string, params: var, callback: var): void {
        if (!helperProcess.running) {
            if (callback) callback(false, undefined, { message: Translation.tr("Wi-Fi helper is unavailable") })
            return
        }
        const id = String(nextRequestId++)
        const next = Object.assign({}, pendingRequests)
        next[id] = {
            method: method,
            callback: callback,
            expiresAt: Date.now() + 12000
        }
        pendingRequests = next
        helperProcess.write(JSON.stringify({ id: id, method: method, params: params ?? {} }) + "\n")
    }

    function handleMessage(message: var): void {
        if (message.event === "profiles_changed") {
            refreshDebounce.restart()
            return
        }
        const id = String(message.id ?? "")
        const pending = pendingRequests[id]
        if (!pending) return
        const next = Object.assign({}, pendingRequests)
        delete next[id]
        pendingRequests = next
        if (pending.callback) pending.callback(message.ok === true, message.result, message.error)
    }

    function failPending(message: string): void {
        const reason = message.trim() || Translation.tr("Wi-Fi helper is unavailable")
        const pending = pendingRequests
        pendingRequests = ({})
        for (const id in pending) {
            if (pending[id].callback) pending[id].callback(false, undefined, { message: reason })
        }
    }

    function checkHealth(): void {
        request("health", {}, function(ok, result, error) {
            root.available = ok && result?.available === true
            root.canModify = root.available && result?.canModify === true
            root.backendVersion = result?.version ?? ""
            root.lastError = ok ? "" : (error?.message ?? Translation.tr("Could not contact NetworkManager"))
            if (root.available) root.refreshProfiles()
        })
    }

    function refreshProfiles(): void {
        if (!helperProcess.running) return
        loading = true
        request("list_profiles", {}, function(ok, result, error) {
            root.loading = false
            if (!ok) {
                root.lastError = error?.message ?? Translation.tr("Could not load saved Wi-Fi networks")
                return
            }
            root.lastError = ""
            root.profiles = Array.isArray(result) ? result.slice() : []
        })
    }

    function runWrite(method: string, params: var, callback: var): void {
        if (operationRunning) {
            if (callback) callback(false, undefined, { message: Translation.tr("Another Wi-Fi operation is in progress") })
            return
        }
        operationRunning = true
        lastError = ""
        request(method, params, function(ok, result, error) {
            root.operationRunning = false
            if (!ok) root.lastError = error?.message ?? Translation.tr("NetworkManager rejected the request")
            else if (result?.activationError) root.lastError = result.activationError
            if (ok) root.refreshProfiles()
            if (callback) callback(ok, result, error)
        })
    }

    function createProfile(params: var, callback: var): void {
        runWrite("create_profile", params, callback)
    }

    function updateProfile(params: var, callback: var): void {
        runWrite("update_profile", params, callback)
    }

    function deleteProfile(profile: var, callback: var): void {
        runWrite("delete_profile", { path: profile.path, uuid: profile.uuid }, callback)
    }

    function activateProfile(profile: var, callback: var): void {
        runWrite("activate_profile", { path: profile.path, uuid: profile.uuid }, callback)
    }

    Process {
        id: helperProcess
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                if (!line || line.trim().length === 0) return
                try {
                    root.handleMessage(JSON.parse(line))
                } catch (error) {
                    root.lastError = Translation.tr("Wi-Fi helper returned invalid data")
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line && line.trim().length > 0) console.warn("[NetworkProfiles]", line.trim())
            }
        }

        onRunningChanged: {
            if (running) {
                readyTimer.restart()
                return
            }
            root.available = false
            root.loading = false
            root.operationRunning = false
            if (root.consumers > 0 && root.lastError.length === 0)
                root.lastError = Translation.tr("Wi-Fi helper is unavailable")
            root.failPending(root.lastError)
        }
    }

    Timer {
        id: readyTimer
        interval: 80
        onTriggered: root.checkHealth()
    }

    Timer {
        id: stopTimer
        interval: 1500
        onTriggered: root.stop()
    }

    Timer {
        id: retryTimer
        interval: 200
        onTriggered: root.start()
    }

    Timer {
        id: refreshDebounce
        interval: 120
        onTriggered: root.refreshProfiles()
    }

    Timer {
        interval: 1000
        repeat: true
        running: Object.keys(root.pendingRequests).length > 0
        onTriggered: {
            const now = Date.now()
            const next = Object.assign({}, root.pendingRequests)
            const expired = []
            for (const id in root.pendingRequests) {
                if (root.pendingRequests[id].expiresAt > now) continue
                expired.push(root.pendingRequests[id])
                delete next[id]
            }
            if (expired.length === 0) return
            root.pendingRequests = next
            root.lastError = Translation.tr("NetworkManager did not respond in time")
            for (const request of expired) {
                if (request.callback) request.callback(false, undefined, { message: root.lastError })
            }
        }
    }
}
