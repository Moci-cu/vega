pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * - Eases fuzzy searching for applications by name
 * - Guesses icon name for window class name
 */
Singleton {
    id: root
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property int resultLimit: 40
    property int queryCacheLimit: 32
    property int iconCacheLimit: 256
    property var queryCache: ({})
    property var iconExistsCache: ({})
    property var guessIconCache: ({})
    property var iconPathCache: ({})
    property var launcherUsage: ({})
    property int usageRevision: 0
    readonly property int maxUsageEntries: 256
    readonly property string launcherUsagePath: FileUtils.trimFileProtocol(
        `${Directories.state}/user/launcher-usage.json`)
    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
    })
    property var regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]

    // Deduped list to fix double icons
    readonly property list<DesktopEntry> list: {
        const seen = new Set();
        return Array.from(DesktopEntries.applications.values).filter(app => {
            if (seen.has(app.id)) return false;
            seen.add(app.id);
            return true;
        });
    }
    property var preppedNamesCache: null
    property var preppedIconsCache: null

    onSloppySearchChanged: queryCache = ({})
    onResultLimitChanged: queryCache = ({})
    onScoreThresholdChanged: queryCache = ({})

    function hasCachedValue(cache, key) {
        return Object.prototype.hasOwnProperty.call(cache, key);
    }

    function rememberCacheValue(cache, key, value, limit) {
        cache[key] = value;
        const keys = Object.keys(cache);
        if (keys.length > limit) delete cache[keys[0]];
        return value;
    }

    function rememberIconGuess(iconName, guess) {
        return rememberCacheValue(root.guessIconCache, iconName, guess, root.iconCacheLimit);
    }

    function clearCaches() {
        queryCache = ({});
        iconExistsCache = ({});
        guessIconCache = ({});
        iconPathCache = ({});
        preppedNamesCache = null;
        preppedIconsCache = null;
    }

    function launcherUsageKey(entry) {
        return `app:${entry?.id || entry?.name || ""}`;
    }

    function launcherUsageBonus(key, now = Date.now()) {
        const usage = root.launcherUsage[String(key ?? "")];
        if (!usage) return 0;
        const count = Math.max(0, Number(usage.count) || 0);
        const ageDays = Math.max(0, (now - (Number(usage.lastUsed) || 0)) / 86400000);
        const countBonus = Math.min(30000, Math.log2(count + 1) * 7000);
        const recencyBonus = Math.max(0, 12000 - ageDays * 400);
        return Math.round(countBonus + recencyBonus);
    }

    function recordLauncherUse(key) {
        key = String(key ?? "");
        if (!/^(app:|action:|command-keyword:|wifi-command:)/.test(key)) return;
        const previous = root.launcherUsage[key] ?? {};
        const next = Object.assign({}, root.launcherUsage);
        next[key] = {
            count: Math.min(100000, Math.max(0, Number(previous.count) || 0) + 1),
            lastUsed: Date.now()
        };
        const keys = Object.keys(next).sort((left, right) => next[right].lastUsed - next[left].lastUsed);
        for (let i = root.maxUsageEntries; i < keys.length; ++i)
            delete next[keys[i]];
        root.launcherUsage = next;
        root.queryCache = ({});
        root.usageRevision++;
        usageSaveTimer.restart();
    }

    function appMatchRank(entry, textScore, search) {
        const name = String(entry?.name ?? "").trim().toLowerCase();
        const query = String(search ?? "").trim().toLowerCase();
        const textRank = name === query ? 3 : name.startsWith(query) ? 2 : textScore;
        return textRank + root.launcherUsageBonus(root.launcherUsageKey(entry)) / 1000000;
    }

    function preparedNames() {
        if (root.preppedNamesCache === null) {
            root.preppedNamesCache = root.list.map(app => ({
                name: Fuzzy.prepare(`${app.name} `),
                entry: app
            }));
        }
        return root.preppedNamesCache;
    }

    function preparedIcons() {
        if (root.preppedIconsCache === null) {
            root.preppedIconsCache = root.list.map(app => ({
                name: Fuzzy.prepare(`${app.icon} `),
                entry: app
            }));
        }
        return root.preppedIconsCache;
    }

    function entryById(id) {
        const directEntry = DesktopEntries.byId(id);
        if (directEntry) return directEntry;
        return root.list.find(entry => (entry.id || entry.name) === id);
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.clearCaches() }
    }

    Timer {
        id: usageSaveTimer

        interval: 150
        onTriggered: usageFile.setText(JSON.stringify(root.launcherUsage))
    }

    FileView {
        id: usageFile

        path: root.launcherUsagePath
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(text() || "{}");
                if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                    throw new Error("invalid launcher usage data");
                const sanitized = {};
                for (const key of Object.keys(parsed)) {
                    const count = Math.floor(Number(parsed[key]?.count));
                    const lastUsed = Number(parsed[key]?.lastUsed);
                    if (count > 0 && Number.isFinite(lastUsed) && lastUsed > 0)
                        sanitized[key] = { count: Math.min(100000, count), lastUsed };
                }
                const keys = Object.keys(sanitized)
                    .sort((left, right) => sanitized[right].lastUsed - sanitized[left].lastUsed);
                for (let i = root.maxUsageEntries; i < keys.length; ++i)
                    delete sanitized[keys[i]];
                root.launcherUsage = sanitized;
            } catch (error) {
                root.launcherUsage = ({});
            }
            root.queryCache = ({});
            root.usageRevision++;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                usageFile.setText("{}");
        }
    }

    function fuzzyQuery(search: string, limit): var { // Idk why list<DesktopEntry> doesn't work
        const effectiveLimit = limit ?? root.resultLimit;
        const cacheKey = `${root.sloppySearch ? "sloppy" : "fuzzy"}:${effectiveLimit}:${root.scoreThreshold}:${search}`;
        if (root.hasCachedValue(root.queryCache, cacheKey)) {
            return root.queryCache[cacheKey];
        }

        if (root.sloppySearch) {
            const results = list.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(obj.name.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => root.appMatchRank(b.entry, b.score, search)
                    - root.appMatchRank(a.entry, a.score, search))
                .slice(0, effectiveLimit)
                .map(item => item.entry)
            return root.rememberCacheValue(root.queryCache, cacheKey, results, root.queryCacheLimit);
        }

        const candidateLimit = Math.min(root.list.length, Math.max(effectiveLimit, 16));
        const results = Fuzzy.go(search, root.preparedNames(), {
            all: true,
            key: "name",
            limit: candidateLimit
        }).sort((a, b) => root.appMatchRank(b.obj.entry, b.score, search)
            - root.appMatchRank(a.obj.entry, a.score, search)).slice(0, effectiveLimit).map(r => {
            return r.obj.entry
        });
        return root.rememberCacheValue(root.queryCache, cacheKey, results, root.queryCacheLimit);
    }

    function iconExists(iconName) {
        if (!iconName || iconName.length == 0) return false;
        if (root.hasCachedValue(root.iconExistsCache, iconName)) return root.iconExistsCache[iconName];
        const exists = (Quickshell.iconPath(iconName, true).length > 0)
            && !iconName.includes("image-missing");
        return root.rememberCacheValue(root.iconExistsCache, iconName, exists, root.iconCacheLimit);
    }

    function iconPath(iconName, fallback) {
        if (!iconName || iconName.length == 0) return fallback ? Quickshell.iconPath(fallback) : "";
        const cacheKey = `${iconName}|${fallback ?? ""}`;
        if (root.hasCachedValue(root.iconPathCache, cacheKey)) return root.iconPathCache[cacheKey];
        return root.rememberCacheValue(root.iconPathCache, cacheKey, Quickshell.iconPath(iconName, fallback), root.iconCacheLimit);
    }

    function getReverseDomainNameAppName(str) {
        return str.split('.').slice(-1)[0]
    }

    function getKebabNormalizedAppName(str) {
        return str.toLowerCase().replace(/\s+/g, "-");
    }

    function getUndescoreToKebabAppName(str) {
        return str.toLowerCase().replace(/_/g, "-");
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";
        const iconName = String(str);
        if (root.hasCachedValue(root.guessIconCache, iconName)) return root.guessIconCache[iconName];

        // Quickshell's desktop entry lookup
        const entry = DesktopEntries.byId(iconName);
        if (entry) return root.rememberIconGuess(iconName, entry.icon);

        // Normal substitutions
        if (substitutions[iconName]) return root.rememberIconGuess(iconName, substitutions[iconName]);
        if (substitutions[iconName.toLowerCase()]) return root.rememberIconGuess(iconName, substitutions[iconName.toLowerCase()]);

        // Regex substitutions
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = iconName.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != iconName) return root.rememberIconGuess(iconName, replacedName);
        }

        // Icon exists -> return as is
        if (iconExists(iconName)) return root.rememberIconGuess(iconName, iconName);


        // Simple guesses
        const lowercased = iconName.toLowerCase();
        if (iconExists(lowercased)) return root.rememberIconGuess(iconName, lowercased);

        const reverseDomainNameAppName = getReverseDomainNameAppName(iconName);
        if (iconExists(reverseDomainNameAppName)) return root.rememberIconGuess(iconName, reverseDomainNameAppName);

        const lowercasedDomainNameAppName = reverseDomainNameAppName.toLowerCase();
        if (iconExists(lowercasedDomainNameAppName)) return root.rememberIconGuess(iconName, lowercasedDomainNameAppName);

        const kebabNormalizedGuess = getKebabNormalizedAppName(iconName);
        if (iconExists(kebabNormalizedGuess)) return root.rememberIconGuess(iconName, kebabNormalizedGuess);

        const undescoreToKebabGuess = getUndescoreToKebabAppName(iconName);
        if (iconExists(undescoreToKebabGuess)) return root.rememberIconGuess(iconName, undescoreToKebabGuess);

        // Search in desktop entries
        const iconSearchResults = Fuzzy.go(iconName, root.preparedIcons(), {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
        if (iconSearchResults.length > 0) {
            const guess = iconSearchResults[0].icon
            if (iconExists(guess)) return root.rememberIconGuess(iconName, guess);
        }

        const nameSearchResults = root.fuzzyQuery(iconName);
        if (nameSearchResults.length > 0) {
            const guess = nameSearchResults[0].icon
            if (iconExists(guess)) return root.rememberIconGuess(iconName, guess);
        }

        // Quickshell's desktop entry lookup
        const heuristicEntry = DesktopEntries.heuristicLookup(iconName);
        if (heuristicEntry) return root.rememberIconGuess(iconName, heuristicEntry.icon);

        // Give up
        return root.rememberIconGuess(iconName, "application-x-executable");
    }
}
