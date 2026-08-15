pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/*
 * Originally from this PR in the original illogical-impulse repo by user SMANahian: https://github.com/end-4/dots-hyprland/pull/2709
 * Couldn't find any license info, so assuming MIT like the rest of the repo.
 * And I couldn't contact the author of the PR, so I ended up copying it here.
*/

Item {
    id: root
    visible: false

    property bool enabled: false
    property string title: ""
    property string artist: ""
    property string album: ""
    property real duration: 0
    property real position: 0
    property int selectedId: 0

    property bool loading: false
    property string error: ""
    property bool instrumental: false
    property var lines: []
    property var _cache: ({})

    property string loadedKey: ""
    property string requestKey: ""
    property int requestId: 0
    property int attempt: 0
    property bool startPending: false

    readonly property int cacheSchemaVersion: 2
    readonly property real cacheTtlMs: 30 * 24 * 60 * 60 * 1000

    readonly property string queryTitle: normalizeTitle(title)
    readonly property string queryArtist: normalizeArtist(artist)
    readonly property string queryAlbum: album.trim()
    readonly property int queryDuration: isFinite(duration) && duration > 0 ? Math.round(duration) : 0
    readonly property string queryKey: `${queryTitle}||${queryArtist}||${queryAlbum}||${queryDuration}`
    readonly property string fetchKey: `${queryKey}||${selectedId}`

    readonly property int currentIndex: syncedLyricIndexForPosition(position)
    readonly property string currentLineText: currentIndex >= 0 ? (root.lines[currentIndex]?.text ?? "") : ""
    readonly property int prevIndex: prevNonEmptyIndex(currentIndex)
    readonly property string prevLineText: prevIndex >= 0 ? (root.lines[prevIndex]?.text ?? "") : ""
    readonly property int nextIndex: nextNonEmptyIndex(currentIndex)
    readonly property string nextLineText: nextIndex >= 0 ? (root.lines[nextIndex]?.text ?? "") : ""
    readonly property string displayText: {
        if (!root.enabled)
            return "";
        if (root.loading)
            return "Fetching lyrics…";
        if (root.instrumental)
            return "Instrumental";
        if (root.error && root.error.length > 0)
            return root.error;
        return root.currentLineText && root.currentLineText.length > 0 ? root.currentLineText : "♪";
    }

    function normalizeTitle(rawTitle) {
        if (!rawTitle)
            return "";

        let cleaned = StringUtils.cleanMusicTitle(rawTitle);

        // Keep trailing suffixes like "Remix", "Version", "Edit" (e.g. "Title - Remix").
        const parts = cleaned.split(" - ");
        let main = parts[0].trim();
        let suffix = parts.slice(1).join(" - ").trim();
        const versionMarker = /\b(remix|version|edit|mix|rework|live|acoustic|remaster(?:ed)?|sped[ -]?up|slowed|nightcore|instrumental|karaoke|tv size)\b/i;
        if (suffix && versionMarker.test(suffix))
            cleaned = `${main} ${suffix}`;
        else
            cleaned = main;

        // Remove parenthetical content except keep featuring info (feat/ft/featuring).
        cleaned = cleaned.replace(/\s*[\(\[\{]([^\)\]\}]*)[\)\]\}]\s*/g, function(_, inner) {
            if (/(?:feat\.?|ft\.?|featuring)/i.test(inner)) {
                const m = inner.replace(/^(?:feat\.?|ft\.?|featuring)\s*/i, '').trim();
                return m ? ` feat. ${m} ` : ' ';
            }
            if (versionMarker.test(inner))
                return ` ${inner} `;
            return ' ';
        }).replace(/\s+/g, " ").trim();

        return cleaned;
    }

    function normalizeArtist(rawArtist) {
        if (!rawArtist)
            return "";

        let cleaned = rawArtist.trim();
        cleaned = cleaned.split(",")[0];
        cleaned = cleaned.split(/ feat\.? /i)[0];
        cleaned = cleaned.split(/ ft\.? /i)[0];
        cleaned = cleaned.split(/ featuring /i)[0];
        cleaned = cleaned.split(/ & /)[0];
        cleaned = cleaned.split(/ x /i)[0];
        return cleaned.trim();
    }

    function parseSyncedLyrics(lrcText) {
        if (!lrcText)
            return [];

        const parsed = [];
        const rawLines = lrcText.split(/\r?\n/);
        const timeTag = /\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]/g;
        const offsetMatch = lrcText.match(/^\s*\[offset\s*:\s*([+-]?\d+)\s*\]\s*$/im);
        const offsetSeconds = offsetMatch ? parseInt(offsetMatch[1], 10) / 1000 : 0;

        for (const rawLine of rawLines) {
            if (!rawLine)
                continue;

            timeTag.lastIndex = 0;
            const times = [];
            let match;
            while ((match = timeTag.exec(rawLine)) !== null) {
                const minutes = parseInt(match[1], 10);
                const seconds = parseInt(match[2], 10);
                const fraction = match[3];
                let millis = 0;
                if (fraction !== undefined) {
                    if (fraction.length === 1)
                        millis = parseInt(fraction, 10) * 100;
                    else if (fraction.length === 2)
                        millis = parseInt(fraction, 10) * 10;
                    else
                        millis = parseInt(fraction.padEnd(3, "0"), 10);
                }
                times.push(Math.max(0, minutes * 60 + seconds + millis / 1000 + offsetSeconds));
            }

            if (times.length === 0)
                continue;

            const text = rawLine.replace(timeTag, "").trim();
            for (const t of times) {
                parsed.push({
                    time: t,
                    text
                });
            }
        }

        parsed.sort((a, b) => a.time - b.time);
        return parsed;
    }

    function syncedLyricIndexForPosition(positionSeconds) {
        if (!root.lines || root.lines.length === 0)
            return -1;

        if (isNaN(positionSeconds) || positionSeconds < 0)
            positionSeconds = 0;

        let lo = 0;
        let hi = root.lines.length - 1;
        let idx = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (root.lines[mid].time <= positionSeconds) {
                idx = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }

        return idx;
    }

    function nextNonEmptyIndex(fromIndex) {
        if (!root.lines || root.lines.length === 0)
            return -1;

        let startIndex = fromIndex;
        if (startIndex < -1)
            startIndex = -1;

        for (let i = startIndex + 1; i < root.lines.length; ++i) {
            const text = root.lines[i].text;
            if (text && text.length > 0)
                return i;
        }

        return -1;
    }

    function prevNonEmptyIndex(fromIndex) {
        if (!root.lines || root.lines.length === 0)
            return -1;

        if (fromIndex <= 0)
            return -1;

        for (let i = fromIndex - 1; i >= 0; --i) {
            const text = root.lines[i].text;
            if (text && text.length > 0)
                return i;
        }

        return -1;
    }

    function buildLyricsSearchUrl(attempt) {
        const baseSearch = "https://lrclib.net/api/search";
        const baseGet = "https://lrclib.net/api/get";
        const title = root.queryTitle;
        const artist = root.queryArtist;
        const album = root.queryAlbum;
        const duration = root.queryDuration;

        if (!title || !artist)
            return "";

        const urls = [];
        if (root.selectedId > 0)
            urls.push(`${baseGet}/${root.selectedId}`);
        if (album && duration > 0)
            urls.push(`${baseGet}?track_name=${encodeURIComponent(title)}&artist_name=${encodeURIComponent(artist)}&album_name=${encodeURIComponent(album)}&duration=${duration}`);

        urls.push(`${baseSearch}?track_name=${encodeURIComponent(title)}&artist_name=${encodeURIComponent(artist)}`);
        urls.push(`${baseSearch}?q=${encodeURIComponent(`${title} ${artist}`)}`);
        urls.push(`${baseSearch}?q=${encodeURIComponent(title)}`);
        return urls[attempt] ?? "";
    }

    function comparableText(value) {
        return String(value ?? "").toLowerCase().replace(/[\s\-_()\[\]{},.'\"!:;?/\\]+/g, " ").trim();
    }

    function pickBestLyricsResult(results) {
        if (!Array.isArray(results) || results.length === 0)
            return null;

        const titleLower = root.comparableText(root.queryTitle);
        const artistLower = root.comparableText(root.queryArtist);
        const albumLower = root.comparableText(root.queryAlbum);
        const duration = root.queryDuration;

        let best = null;
        let bestScore = -Infinity;

        for (const item of results) {
            const syncedLyrics = item?.syncedLyrics ?? "";
            if ((!syncedLyrics || syncedLyrics.length === 0) && !item?.instrumental)
                continue;

            let score = 0;
            const itemTitle = root.comparableText(item?.trackName ?? item?.name);
            const itemArtist = root.comparableText(item?.artistName);
            const itemAlbum = root.comparableText(item?.albumName);

            if (itemArtist && itemArtist === artistLower)
                score += 300;
            else if (itemArtist && (itemArtist.includes(artistLower) || artistLower.includes(itemArtist)))
                score += 80;
            else
                score -= 300;

            if (itemTitle && itemTitle === titleLower)
                score += 300;
            else if (itemTitle && (itemTitle.includes(titleLower) || titleLower.includes(itemTitle)))
                score += 80;
            else
                score -= 300;

            if (albumLower && itemAlbum === albumLower)
                score += 100;

            if (duration > 0 && typeof item?.duration === "number") {
                const diff = Math.abs(item.duration - duration);
                if (diff <= 2)
                    score += 400;
                else if (diff <= 5)
                    score += 200;
                else if (diff <= 10)
                    score += 50;
                else
                    score -= Math.min(diff * 4, 400);
            }

            if (duration > 0 && syncedLyrics.length > 0) {
                const candidateLines = root.parseSyncedLyrics(syncedLyrics);
                const lastTimestamp = candidateLines.length > 0 ? candidateLines[candidateLines.length - 1].time : 0;
                if (lastTimestamp > duration + 5)
                    score -= 500 + Math.min((lastTimestamp - duration) * 5, 500);
            }

            if (item?.instrumental)
                score -= 1000;

            if (syncedLyrics.length < 32)
                score -= 60;

            score += Math.min(syncedLyrics.length, 4000) / 400;

            if (score > bestScore) {
                bestScore = score;
                best = item;
            }
        }

        return best;
    }

    function resetState() {
        root.loading = false;
        root.error = "";
        root.instrumental = false;
        root.lines = [];
        root.loadedKey = "";
        root.requestKey = "";
        root.attempt = 0;
        root.startPending = false;
    }

    function ensureFetched() {
        if (!root.enabled)
            return;

        if (!root.queryTitle || !root.queryArtist) {
            root.error = "No track info";
            return;
        }

        if (root.loadedKey === root.fetchKey)
            return;

        if (root.loading && root.requestKey === root.fetchKey)
            return;

        if (fetcher.running && fetcher.requestKey === root.fetchKey)
            return;

        root.requestId += 1;
        root.attempt = 0;
        root.requestKey = root.fetchKey;
        root.loading = true;
        root.error = "";
        root.instrumental = false;
        root.lines = [];

        if (fetcher.running) {
            root.startPending = true;
            return;
        }

        root.fetchAttempt(root.requestId);
    }

    function fetchAttempt(requestId) {
        if (requestId !== root.requestId)
            return;
        if (root.requestKey !== root.fetchKey)
            return;

        const url = root.buildLyricsSearchUrl(root.attempt);
        if (!url) {
            root.loading = false;
            root.error = "No synced lyrics";
            return;
        }

        fetcher.requestId = requestId;
        fetcher.requestKey = root.requestKey;
        fetcher.attempt = root.attempt;
        fetcher.command = ["curl", "-sL", url];
        fetcher.running = true;
    }

    Timer {
        id: fetchDebounce
        interval: 250
        repeat: false
        onTriggered: root.ensureFetched()
    }

    onFetchKeyChanged: {
        root.resetState();
        const shouldFetch = root.enabled && root.queryTitle && root.queryArtist;
        root.loading = shouldFetch;

        if (lyricFileView.isInitialLoad) {
            if (shouldFetch)
                fetchDebounce.restart();
            return;
        }
        
        const cached = getCached(root.queryTitle, root.queryArtist, root.queryAlbum, root.queryDuration);
        if (cached) {
            root.instrumental = cached.instrumental || false;
            root.lines = cached.lines || [];
            root.loading = false;
            root.error = "";
            root.loadedKey = root.fetchKey;
        } else if (shouldFetch) {
            fetchDebounce.restart();
        }
    }


    function cacheKey(track, artist, album, duration) {
        return `${track}||${artist}||${album}||${duration}`;
    }

    function getCached(track, artist, album, duration) {
        if (root.selectedId > 0)
            return null;
        const key = root.cacheKey(track, artist, album, duration);
        const cached = root._cache[key] ?? null;
        if (!cached || cached.schemaVersion !== root.cacheSchemaVersion)
            return null;
        if (!cached.fetchedAt || Date.now() - cached.fetchedAt > root.cacheTtlMs)
            return null;
        if (duration > 0 && cached.sourceDuration > 0 && Math.abs(cached.sourceDuration - duration) > 5)
            return null;
        return cached;
    }

    function setCache(track, artist, album, duration, data) {
        if (root.selectedId > 0)
            return;
        const key = root.cacheKey(track, artist, album, duration);
        root._cache[key] = Object.assign({}, data, {
            schemaVersion: root.cacheSchemaVersion,
            fetchedAt: Date.now()
        });
        saveCache();
    }

    function saveCache() {
        // console.log("[Lyrics] Sacing, total songs:", Object.keys(root._cache).length);
        lyricFileView.setText(JSON.stringify(root._cache, null, 2)); 
    }

    FileView {
        id: lyricFileView
        path: Directories.lyricsPath
        property bool isInitialLoad: true
        
        onLoaded: {
            if (isInitialLoad) {
                try {
                    const loaded = JSON.parse(lyricFileView.text() || "{}");
                    const now = Date.now();
                    const validCache = {};
                    for (const key of Object.keys(loaded)) {
                        const entry = loaded[key];
                        if (entry?.schemaVersion === root.cacheSchemaVersion
                                && entry.fetchedAt
                                && now - entry.fetchedAt <= root.cacheTtlMs)
                            validCache[key] = entry;
                    }
                    root._cache = validCache;
                    // console.log("[Cache] Loaded, total songs:", Object.keys(loaded).length);
                } catch (e) {
                    root._cache = {};
                }
                isInitialLoad = false;
                
                // Cache yüklendikten sonra tekrar kontrol et
                if (root.fetchKey) {
                    const cached = getCached(root.queryTitle, root.queryArtist, root.queryAlbum, root.queryDuration);
                    if (cached) {
                        root.instrumental = cached.instrumental || false;
                        root.lines = cached.lines || [];
                        root.loading = false;
                        root.error = "";
                        root.loadedKey = root.fetchKey;
                    }
                }
            }
        }
    }


    onSelectedIdChanged: {
        root.resetState();
        if (root.enabled)
            fetchDebounce.restart();
    }

    onEnabledChanged: {
        if (root.enabled)
            fetchDebounce.restart();
        else {
            root.loading = false;
            root.startPending = false;
        }
    }

    Process {
        id: fetcher
        property int requestId: 0
        property string requestKey: ""
        property int attempt: 0
        running: false
        command: ["curl", "-sL", "https://lrclib.net/api/search?q="]
        stdout: StdioCollector {
            onStreamFinished: {
                const requestId = fetcher.requestId;
                const requestKey = fetcher.requestKey;

                if (requestKey !== root.fetchKey) {
                    if (root.startPending) {
                        root.startPending = false;
                        if (root.enabled)
                            root.fetchAttempt(root.requestId);
                    }
                    return;
                }

                if (text.length === 0) {
                    root.attempt += 1;
                    root.fetchAttempt(requestId);
                    return;
                }

                try {
                    const parsed = JSON.parse(text);
                    let results = [];
                    
                    if (Array.isArray(parsed)) {
                        results = parsed;
                    } else if (parsed && typeof parsed === "object" && !parsed.code && !parsed.error) {
                        results = [parsed];
                    }

                    let filtered = results;

                    if (root.queryArtist) {
                        const artistLower = root.queryArtist.toLowerCase();
                        const matchingArtist = results.filter(item => (item?.artistName ?? "").toLowerCase() === artistLower);
                        if (matchingArtist.length > 0)
                            filtered = matchingArtist;
                    }

                    const best = root.pickBestLyricsResult(filtered);
                    if (!best) {
                        root.attempt += 1;
                        root.fetchAttempt(requestId);
                        return;
                    }

                    root.instrumental = best.instrumental ?? false;
                    root.lines = root.parseSyncedLyrics(best.syncedLyrics ?? "");

                    if (root.lines.length === 0 && !root.instrumental) {
                        root.attempt += 1;
                        root.fetchAttempt(requestId);
                        return;
                    }

                    root.setCache(root.queryTitle, root.queryArtist, root.queryAlbum, root.queryDuration, {
                        instrumental: root.instrumental,
                        lines: root.lines,
                        sourceId: best.id ?? 0,
                        sourceDuration: best.duration ?? 0
                    });

                    root.loading = false;
                    root.error = root.lines.length === 0 && root.instrumental ? "Instrumental" : "";
                    root.loadedKey = requestKey;
                } catch (e) {
                    root.attempt += 1;
                    root.fetchAttempt(requestId);
                }
            }
        }
    }
}
