pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions


Item {
    id: root
    visible: false

    signal lyricsUpdated(string lyrics)

    readonly property var geniusApiKey: KeyringStorage.keyringData?.apiKeys?.genius
    readonly property bool loading: fetchLyricsProcess.running || pendingRequest !== null

    property int latestRequestId: 0
    property int activeRequestId: 0
    property var pendingRequest: null

    function startPendingRequest() {
        if (fetchLyricsProcess.running || pendingRequest === null) return

        const request = pendingRequest
        pendingRequest = null
        activeRequestId = request.id
        console.log("[Genius Lyrics] Fetching lyrics for", request.artist, "-", request.title)
        fetchLyricsProcess.command = ["node", Directories.geniusLyricsScriptPath, root.geniusApiKey, request.artist, request.title]
        fetchLyricsProcess.running = true
    }

    function fetchLyrics(artist, title) {
        const requestId = ++latestRequestId
        pendingRequest = {
            id: requestId,
            artist: artist,
            title: title
        }
        startPendingRequest()
    }

    Process {
        id: fetchLyricsProcess
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.activeRequestId === root.latestRequestId) root.lyricsUpdated(this.text)
            }
        }

        onExited: {
            if (root.pendingRequest !== null) Qt.callLater(root.startPendingRequest)
        }
    }
}
