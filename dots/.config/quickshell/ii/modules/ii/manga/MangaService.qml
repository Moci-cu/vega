import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    visible: false

    readonly property string apiUrl: "http://127.0.0.1:5150"
    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/manga/manga_server.py`)

    property string backendState: "idle"
    property string backendError: ""
    property bool initialized: false

    property var mangaList: []
    property bool isFetchingManga: false
    property string mangaError: ""
    property bool hasMoreManga: false
    property int currentOffset: 0
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentOrigin: ""
    property int listRequestId: 0

    property var currentManga: null
    property string pendingMangaId: ""
    property bool isFetchingDetail: false
    property string detailError: ""
    property int detailRequestId: 0

    property var currentChapters: []
    property bool isFetchingChapters: false
    property bool chaptersLoaded: false
    property string chaptersError: ""
    property int chaptersRequestId: 0
    property int chaptersProgress: 0
    property string chaptersPollPath: ""
    property bool chaptersPollInFlight: false

    property var chapterPages: []
    property bool isFetchingPages: false
    property string pagesError: ""
    property string currentChapterId: ""
    property int pagesRequestId: 0

    property var libraryList: []
    property bool libraryLoaded: false

    Process {
        id: serverProcess
        command: ["python3", root.scriptPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.log("[Manga backend]", text.trim())
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("[Manga backend]", text.trim())
            }
        }
        onExited: function(code) {
            if (root.backendState !== "ready" && code !== 0)
                root.backendError = "Backend exited with code " + code
        }
    }

    Timer {
        id: healthTimer
        interval: 500
        repeat: true
        onTriggered: root._probeBackend()
    }

    Timer {
        id: keepAliveTimer
        interval: 5000
        repeat: true
        onTriggered: {
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== 4) return
                if (xhr.status !== 200) {
                    backendState = "idle"
                    keepAliveTimer.stop()
                    healthAttempts = 0
                    healthTimer.start()
                }
            }
            xhr.open("GET", apiUrl + "/health?_=" + Date.now())
            xhr.send()
        }
    }

    Timer {
        id: progressTimer
        interval: 500
        repeat: true
        onTriggered: {
            if (backendState !== "ready") return
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== 4 || xhr.status < 200 || xhr.status >= 300) return
                try {
                    var data = JSON.parse(xhr.responseText)
                    chaptersProgress = data.current || 0
                } catch (e) {}
            }
            xhr.open("GET", apiUrl + "/chapters_progress?_=" + Date.now())
            xhr.send()
        }
    }

    Timer {
        id: chaptersPollTimer
        interval: 700
        repeat: true
        onTriggered: root._pollChapters()
    }

    property int healthAttempts: 0

    function ensureStarted() {
        if (backendState === "ready") {
            _bootstrap()
            return
        }
        backendState = "connecting"
        backendError = ""
        healthAttempts = 0
        healthTimer.start()
        _probeBackend()
    }

    function retryBackend() {
        backendState = "idle"
        ensureStarted()
    }

    function _probeBackend() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4)
                return
            if (xhr.status === 200) {
                healthTimer.stop()
                backendState = "ready"
                backendError = ""
                keepAliveTimer.start()
                _bootstrap()
                return
            }

            healthAttempts++
            if (!serverProcess.running)
                serverProcess.running = true
            if (healthAttempts >= 20) {
                healthTimer.stop()
                backendState = "error"
                backendError = "Manga backend did not become ready"
            }
        }
        xhr.open("GET", apiUrl + "/health")
        xhr.send()
    }

    function _bootstrap() {
        if (!libraryLoaded)
            fetchLibrary()
        if (!initialized) {
            initialized = true
            fetchByOrigin("", true)
        }
    }

    function _request(method, path, payload, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4)
                return
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    callback(null, JSON.parse(xhr.responseText))
                } catch (error) {
                    callback("Invalid JSON response", null)
                }
            } else {
                var message = "HTTP " + xhr.status
                try {
                    var response = JSON.parse(xhr.responseText)
                    if (response.error)
                        message = response.error
                } catch (error) {}
                callback(message, null)
            }
        }
        var requestPath = path
        if (method === "GET")
            requestPath += (path.indexOf("?") >= 0 ? "&" : "?")
                + "_=" + Date.now()
        xhr.open(method, apiUrl + requestPath)
        if (payload !== null) {
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.send(JSON.stringify(payload))
        } else {
            xhr.send()
        }
    }

    function _originType(origin) {
        if (origin === "ja")
            return "Manga"
        if (origin === "ko")
            return "Manhwa"
        if (origin === "zh")
            return "Manhua"
        return ""
    }

    function _applyListResponse(data, reset) {
        var items = data && Array.isArray(data.results) ? data.results : []
        mangaList = reset ? items : mangaList.concat(items)
        hasMoreManga = Boolean(data && data.hasMore)
        currentOffset = data && data.nextOffset !== undefined
            ? Number(data.nextOffset)
            : currentOffset + items.length
    }

    function fetchByOrigin(origin, reset) {
        if (backendState !== "ready")
            return
        var shouldReset = reset !== false
        currentOrigin = origin
        currentSearchText = ""
        if (shouldReset) {
            mangaList = []
            currentOffset = 0
            latestPage = 1
        }

        var requestId = ++listRequestId
        isFetchingManga = true
        mangaError = ""
        var path
        if (origin === "")
            path = "/hot"
        else if (origin === "latest")
            path = "/latest?page=" + latestPage
        else
            path = "/browse?type=" + encodeURIComponent(_originType(origin))
                + "&offset=" + currentOffset

        _request("GET", path, null, function(error, data) {
            if (requestId !== listRequestId)
                return
            isFetchingManga = false
            if (error) {
                mangaError = error
                return
            }
            _applyListResponse(data, shouldReset)
        })
    }

    function searchManga(query, reset) {
        if (backendState !== "ready")
            return
        var text = String(query || "").trim()
        if (!text) {
            fetchByOrigin(currentOrigin, true)
            return
        }
        var shouldReset = reset !== false
        currentSearchText = text
        if (shouldReset) {
            mangaList = []
            currentOffset = 0
        }

        var requestId = ++listRequestId
        isFetchingManga = true
        mangaError = ""
        var path = "/search?q=" + encodeURIComponent(text)
            + "&type=" + encodeURIComponent(_originType(currentOrigin))
            + "&offset=" + currentOffset
        _request("GET", path, null, function(error, data) {
            if (requestId !== listRequestId)
                return
            isFetchingManga = false
            if (error) {
                mangaError = error
                return
            }
            _applyListResponse(data, shouldReset)
        })
    }

    function fetchNextMangaPage() {
        if (!hasMoreManga || isFetchingManga)
            return
        if (currentSearchText)
            searchManga(currentSearchText, false)
        else if (currentOrigin === "latest") {
            latestPage++
            fetchByOrigin("latest", false)
        } else {
            fetchByOrigin(currentOrigin, false)
        }
    }

    function retryList() {
        if (currentSearchText)
            searchManga(currentSearchText, true)
        else
            fetchByOrigin(currentOrigin, true)
    }

    function fetchMangaDetail(mangaId) {
        if (backendState !== "ready")
            return
        var requestId = ++detailRequestId
        pendingMangaId = mangaId
        currentManga = null
        currentChapters = []
        chaptersPollTimer.stop()
        progressTimer.stop()
        chaptersPollInFlight = false
        isFetchingDetail = true
        detailError = ""
        chaptersLoaded = false
        chaptersError = ""
        _request("GET", "/info?id=" + encodeURIComponent(mangaId), null, function(error, data) {
            if (requestId !== detailRequestId)
                return
            if (error || !data || data.error) {
                isFetchingDetail = false
                detailError = error || data.error || "Manga not found"
                return
            }
            isFetchingDetail = false
            console.log("[MangaService] manga info loaded:", data.id, "latestChapterId:", data.latestChapterId)
            currentManga = data
            // Auto-fetch chapters in background
            if (data.latestChapterId)
                _fetchChaptersForManga(data)
        })
    }

    function _fetchChaptersForManga(manga) {
        var requestId = ++chaptersRequestId
        isFetchingChapters = true
        chaptersError = ""
        chaptersProgress = 0
        chaptersPollTimer.stop()
        progressTimer.stop()
        chaptersPollInFlight = false
        chaptersPollPath = "/chapters?mangaId=" + encodeURIComponent(manga.id)
            + "&latestChapterId=" + encodeURIComponent(manga.latestChapterId)
        _requestChapters(requestId)
    }

    function _pollChapters() {
        if (!isFetchingChapters || !chaptersPollPath || chaptersPollInFlight)
            return
        _requestChapters(chaptersRequestId)
    }

    function _requestChapters(requestId) {
        chaptersPollInFlight = true
        _request("GET", chaptersPollPath, null, function(error, data) {
            chaptersPollInFlight = false
            if (requestId !== chaptersRequestId)
                return
            isFetchingDetail = false
            if (error) {
                console.warn("[MangaService] chapters error:", error)
                chaptersError = error
                isFetchingChapters = false
                chaptersPollTimer.stop()
                return
            }

            var chapters = Array.isArray(data) ? data
                : data && Array.isArray(data.chapters) ? data.chapters : []
            currentChapters = chapters
            chaptersProgress = data && data.current !== undefined ? Number(data.current) : chapters.length
            chaptersError = data && data.error ? data.error : ""
            chaptersLoaded = chapters.length > 0

            var complete = Array.isArray(data) || !data || data.complete !== false
            if (complete) {
                isFetchingChapters = false
                chaptersPollTimer.stop()
                chaptersLoaded = true
                console.log("[MangaService] chapters loaded:", currentChapters.length, "chaptersLoaded:", chaptersLoaded)
            } else if (!chaptersPollTimer.running) {
                chaptersPollTimer.start()
            }
        })
    }

    function fetchChapters() {
        if (backendState !== "ready" || !currentManga || !currentManga.latestChapterId)
            return
        if (chaptersLoaded || isFetchingChapters)
            return
        _fetchChaptersForManga(currentManga)
    }

    function refetchChapters() {
        if (backendState !== "ready" || !currentManga)
            return
        isFetchingChapters = true
        chaptersLoaded = false
        currentChapters = []
        chaptersError = ""
        chaptersProgress = 0
        chaptersPollTimer.stop()
        progressTimer.stop()
        chaptersPollInFlight = false
        _request("GET", "/clear_cache?mangaId=" + encodeURIComponent(currentManga.id), null, function(error) {
            if (!error)
                _fetchChaptersForManga(currentManga)
            else {
                isFetchingChapters = false
                chaptersPollTimer.stop()
                chaptersError = error
            }
        })
    }

    function retryDetail() {
        if (pendingMangaId)
            fetchMangaDetail(pendingMangaId)
    }

    function fetchChapterPages(chapterId) {
        if (backendState !== "ready")
            return
        var requestId = ++pagesRequestId
        currentChapterId = chapterId
        chapterPages = []
        isFetchingPages = true
        pagesError = ""
        _request("GET", "/pages?chapterId=" + encodeURIComponent(chapterId), null, function(error, data) {
            if (requestId !== pagesRequestId)
                return
            isFetchingPages = false
            if (error) {
                pagesError = error
                return
            }
            if (!Array.isArray(data) || data.length === 0) {
                pagesError = "No pages found for this chapter"
                return
            }
            var mapped = data.map(function(page, index) {
                return { index: index, url: page.img || "" }
            })
            chapterPages = []
            chapterPages = mapped
        })
    }

    function retryPages() {
        if (currentChapterId)
            fetchChapterPages(currentChapterId)
    }

    function clearChapterPages() {
        pagesRequestId++
        chapterPages = []
        pagesError = ""
        currentChapterId = ""
        isFetchingPages = false
    }

    function _sortLibrary(list) {
        return list.slice().sort(function(a, b) {
            var aTime = a.lastReadAt || ""
            var bTime = b.lastReadAt || ""
            if (aTime === bTime) return 0
            return aTime > bTime ? -1 : 1
        })
    }

    function fetchLibrary() {
        _request("GET", "/library", null, function(error, data) {
            libraryLoaded = true
            if (!error && Array.isArray(data))
                libraryList = _sortLibrary(data)
        })
    }

    function _updateLibrary(path, payload) {
        _request("POST", path, payload, function(error, data) {
            if (error) {
                console.warn("[Manga] Library update failed:", error)
                return
            }
            if (Array.isArray(data))
                libraryList = _sortLibrary(data)
        })
    }

    function addToLibrary(manga) {
        if (!manga || isInLibrary(manga.id))
            return
        _updateLibrary("/library/add", {
            id: manga.id,
            title: manga.title,
            coverUrl: manga.image || manga.coverUrl || "",
            addedAt: new Date().toISOString()
        })
    }

    function removeFromLibrary(mangaId) {
        _updateLibrary("/library/remove", { id: mangaId })
    }

    function updateLastRead(mangaId, chapterId, chapterNum, lastReadPage) {
        if (!isInLibrary(mangaId))
            return
        _updateLibrary("/library/progress", {
            id: mangaId,
            chapterId: chapterId,
            chapterNum: chapterNum,
            lastReadPage: lastReadPage || 0
        })
    }

    function isInLibrary(mangaId) {
        return libraryList.some(function(entry) {
            return entry.id === mangaId
        })
    }

    function getLibraryEntry(mangaId) {
        for (var index = 0; index < libraryList.length; index++) {
            if (libraryList[index].id === mangaId)
                return libraryList[index]
        }
        return null
    }
}
