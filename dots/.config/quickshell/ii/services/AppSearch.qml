pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell

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
    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .filter((app, index, self) => 
            index === self.findIndex((t) => (
                t.id === app.id
            ))
    )
    
    readonly property var preppedNames: list.map(a => ({
        name: Fuzzy.prepare(`${a.name} `),
        entry: a
    }))

    readonly property var preppedIcons: list.map(a => ({
        name: Fuzzy.prepare(`${a.icon} `),
        entry: a
    }))

    onSloppySearchChanged: queryCache = ({})
    onResultLimitChanged: queryCache = ({})

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
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.clearCaches() }
    }

    function fuzzyQuery(search: string, limit): var { // Idk why list<DesktopEntry> doesn't work
        const effectiveLimit = limit ?? root.resultLimit;
        const cacheKey = `${root.sloppySearch ? "sloppy" : "fuzzy"}:${effectiveLimit}:${search}`;
        if (root.hasCachedValue(root.queryCache, cacheKey)) {
            return root.queryCache[cacheKey];
        }

        if (root.sloppySearch) {
            const results = list.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(obj.name.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
                .slice(0, effectiveLimit)
                .map(item => item.entry)
            return root.rememberCacheValue(root.queryCache, cacheKey, results, root.queryCacheLimit);
        }

        const results = Fuzzy.go(search, preppedNames, {
            all: true,
            key: "name",
            limit: effectiveLimit
        }).map(r => {
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
        const iconSearchResults = Fuzzy.go(iconName, preppedIcons, {
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
