pragma Singleton

import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property string query: ""
    property int resultLimit: 15

    readonly property list<string> searchPrefixes: [Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch, Config.options.search.prefix.fileSearch, Config.options.search.prefix.window]

    function hasPrefix(prefix) {
        return prefix.length > 0 && root.query.startsWith(prefix);
    }

    function matchedPrefix() {
        return root.searchPrefixes.find(prefix => prefix.length > 0 && root.query.startsWith(prefix)) ?? "";
    }

    function ensurePrefix(prefix) {
        const currentPrefix = root.matchedPrefix();
        if (currentPrefix.length > 0) {
            root.query = prefix + root.query.slice(currentPrefix.length);
        } else {
            root.query = prefix + root.query;
        }
    }

    // https://specifications.freedesktop.org/menu/latest/category-registry.html
    property list<string> mainRegisteredCategories: ["AudioVideo", "Development", "Education", "Game", "Graphics", "Network", "Office", "Science", "Settings", "System", "Utility"]
    property list<string> appCategories: DesktopEntries.applications.values.reduce((acc, entry) => {
        for (const category of entry.categories) {
            if (!acc.includes(category) && mainRegisteredCategories.includes(category)) {
                acc.push(category);
            }
        }
        return acc;
    }, []).sort()

    // Load user action scripts from ~/.config/illogical-impulse/actions/
    // Uses FolderListModel to auto-reload when scripts are added/removed
    property var userActionScripts: {
        const actions = [];
        for (let i = 0; i < userActionsFolder.count; i++) {
            const fileName = userActionsFolder.get(i, "fileName");
            const filePath = userActionsFolder.get(i, "filePath");
            if (fileName && filePath) {
                const actionName = fileName.replace(/\.[^/.]+$/, ""); // strip extension
                actions.push({
                    action: actionName,
                    execute: ((path) => (args) => {
                        Quickshell.execDetached([path, ...(args ? args.split(" ") : [])]);
                    })(FileUtils.trimFileProtocol(filePath.toString()))
                });
            }
        }
        return actions;
    }

    FolderListModel {
        id: userActionsFolder
        folder: Qt.resolvedUrl(Directories.userActions)
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args != '' ? [`${args}`] : [])]);
            }
        },
        {
            action: "dark",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
            }
        },
        {
            action: "konachanwallpaper",
            execute: () => {
                Quickshell.execDetached([Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]);
            }
        },
        {
            action: "light",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
            }
        },
        {
            action: "killall",
            execute: () => {
                const windows = HyprlandData.windowList.filter(win => win.address)
                for (const win of windows) {
                    Hyprland.dispatch(`hl.dsp.window.close({window = "address:${win.address}"})`)
                }
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) {
                    // Invalid if doesn't start with numbers
                    Quickshell.execDetached(["notify-send", Translation.tr("Superpaste"), Translation.tr("Usage: <tt>%1superpaste NUM_OF_ENTRIES[i]</tt>\nSupply <tt>i</tt> when you want images\nExamples:\n<tt>%1superpaste 4i</tt> for the last 4 images\n<tt>%1superpaste 7</tt> for the last 7 entries").arg(Config.options.search.prefix.action), "-a", "Shell"]);
                    return;
                }
                const syntaxMatch = /^(?:(\d+)(i)?)/.exec(args.trim());
                const count = syntaxMatch[1] ? parseInt(syntaxMatch[1]) : 1;
                const isImage = !!syntaxMatch[2];
                Cliphist.superpaste(count, isImage);
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args);
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                Hyprland.dispatch(`hl.dsp.global("quickshell:wallpaperSelectorToggle")`)
            }
        },
        {
            action: "wipeclipboard",
            execute: () => {
                Cliphist.wipe();
            }
        },
        {
            action: "genius",
            execute: args => {
                if (!args || args.trim().length === 0) {
                    Quickshell.execDetached(["notify-send", "Genius API", 
                        Translation.tr("Usage: /genius YOUR_API_KEY"), "-a", "Shell"]);
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", "genius"], args.trim());
                Quickshell.execDetached(["notify-send", "Genius API", Translation.tr("API key saved!"), "-a", "Shell"]);
            }
        },
    ]

    // Combined built-in and user actions
    property var allActions: searchActions.concat(userActionScripts)

    property string mathResult: ""
    property bool clipboardWorkSafetyActive: {
        const enabled = Config.options.workSafety.enable.clipboard;
        const sensitiveNetwork = (StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
        return enabled && sensitiveNetwork;
    }

    function mathExpression(query) {
        if (Config.options.search.prefix.math.length > 0 && query.startsWith(Config.options.search.prefix.math)) {
            return query.slice(Config.options.search.prefix.math.length).trim();
        }
        if (/^\d/.test(query)) {
            return query.trim();
        }
        return "";
    }

    function updateNonAppSearches() {
        const query = root.query;
        const mathExpr = root.mathExpression(query);
        if (mathExpr.length > 0) {
            root.mathResult = "";
            mathProc.running = false;
            nonAppResultsTimer.restart();
        } else {
            nonAppResultsTimer.stop();
            mathProc.running = false;
            root.mathResult = "";
        }

        if (!root.hasPrefix(Config.options.search.prefix.fileSearch)) {
            fileSearchTimer.stop();
            fileProc.running = false;
            if (root.fileResults.length > 0) root.fileResults = [];
            return;
        }

        const fileExpr = query.slice(Config.options.search.prefix.fileSearch.length).trim();
        if (fileExpr.length < 2) {
            fileSearchTimer.stop();
            fileProc.running = false;
            if (root.fileResults.length > 0) root.fileResults = [];
            return;
        }

        fileSearchTimer.expression = fileExpr;
        fileSearchTimer.restart();
    }

    function containsUnsafeLink(entry) {
        if (entry == undefined)
            return false;
        const unsafeKeywords = Config.options.workSafety.triggerCondition.linkKeywords;
        return StringUtils.stringListContainsSubstring(entry.toLowerCase(), unsafeKeywords);
    }

    function resultActions(entry, limit) {
        if (!entry) return [];
        const actions = entry.actions;
        if (typeof actions === "function") return actions(limit);
        return limit !== undefined ? (actions ?? []).slice(0, limit) : actions ?? [];
    }

    function clipboardResult(entry, index, array) {
        const mightBlurImage = Cliphist.entryIsImage(entry) && root.clipboardWorkSafetyActive;
        let shouldBlurImage = mightBlurImage;
        if (mightBlurImage) {
            shouldBlurImage = shouldBlurImage && (root.containsUnsafeLink(array[index - 1]) || root.containsUnsafeLink(array[index + 1]));
        }
        const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`;
        return {
            key: `clipboard:${entry.match(/^\s*(\S+)/)?.[1] ?? index}`,
            rawValue: entry,
            name: StringUtils.cleanCliphistEntry(entry),
            verb: "",
            type: type,
            execute: () => Cliphist.copy(entry),
            actions: limit => [
                {
                    name: Translation.tr("Copy"),
                    iconName: "content_copy",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => Cliphist.copy(entry)
                },
                {
                    name: Translation.tr("Delete"),
                    iconName: "delete",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => Cliphist.deleteEntry(entry)
                }
            ].slice(0, limit ?? 2),
            blurImage: shouldBlurImage
        };
    }

    function emojiResult(entry) {
        const emoji = entry.match(/^\s*(\S+)/)?.[1] || "";
        return {
            key: `emoji:${emoji}:${entry}`,
            rawValue: entry,
            name: entry.replace(/^\s*\S+\s+/, ""),
            iconName: emoji,
            iconType: LauncherSearchResult.IconType.Text,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Emoji"),
            execute: () => {
                Quickshell.clipboardText = entry.match(/^\s*(\S+)/)?.[1];
            }
        };
    }

    function mathResultEntry() {
        return {
            key: "math",
            name: root.mathResult,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Math result"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: "calculate",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                Quickshell.clipboardText = root.mathResult;
            }
        };
    }

    function fileResult(entry) {
        return {
            key: `file:${entry}`,
            type: Translation.tr("File"),
            name: entry,
            verb: Translation.tr("Open"),
            iconName: "file_open",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => Quickshell.execDetached(["xdg-open", entry])
        };
    }

    function appAction(action) {
        return {
            name: action.name,
            iconName: action.icon,
            iconType: LauncherSearchResult.IconType.System,
            execute: () => {
                if (!action.runInTerminal) {
                    action.execute();
                    return;
                }
                Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(action.command.join(" "))}'`]);
            }
        };
    }

    function appResult(entry) {
        return {
            key: `app:${entry.id || entry.name}`,
            type: Translation.tr("App"),
            id: entry.id,
            name: entry.name,
            iconName: entry.icon,
            iconType: LauncherSearchResult.IconType.System,
            verb: Translation.tr("Open"),
            execute: () => {
                if (!entry.runInTerminal) {
                    entry.execute();
                    return;
                }
                Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(entry.command.join(" "))}'`]);
            },
            comment: entry.comment,
            runInTerminal: entry.runInTerminal,
            genericName: entry.genericName,
            keywords: entry.keywords,
            actions: limit => entry.actions.slice(0, limit ?? entry.actions.length).map(action => root.appAction(action))
        };
    }

    function windowSearchText(win) {
        return [win.class, win.initialClass, win.title, win.initialTitle]
            .filter(value => value && String(value).length > 0)
            .join(" ")
    }

    function focusWindow(win) {
        Hyprland.dispatch(`hl.dsp.focus({window = "address:${win.address}"})`)
        GlobalStates.overviewOpen = false
    }

    function windowResult(win) {
        const appClass = win.class || win.initialClass || ""
        const title = win.title || win.initialTitle || appClass || Translation.tr("Untitled window")
        return {
            key: `window:${win.address}`,
            type: Translation.tr("Window"),
            name: title,
            iconName: AppSearch.guessIcon(appClass),
            iconType: LauncherSearchResult.IconType.System,
            verb: Translation.tr("Focus"),
            execute: () => root.focusWindow(win),
            actions: limit => [
                {
                    name: Translation.tr("Close"),
                    iconName: "close",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => Hyprland.dispatch(`hl.dsp.window.close({window = "address:${win.address}"})`)
                }
            ].slice(0, limit ?? 1)
        }
    }

    function windowResults(search) {
        const activeWorkspaceId = HyprlandData.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 0
        const windows = HyprlandData.windowList
            .filter(win => win.workspace?.id === activeWorkspaceId)
            .sort((a, b) => (a.focusHistoryID ?? 999999) - (b.focusHistoryID ?? 999999))

        if (search.length === 0) return windows.slice(0, root.resultLimit)

        const preppedWindows = windows.map(win => ({
            name: Fuzzy.prepare(root.windowSearchText(win)),
            entry: win
        }))

        return Fuzzy.go(search, preppedWindows, {
            all: true,
            key: "name",
            limit: root.resultLimit
        }).map(r => r.obj.entry)
    }

    function commandResult() {
        return {
            key: "command",
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.shellCommand).replace("file://", ""),
            verb: Translation.tr("Run"),
            type: Translation.tr("Command"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: "terminal",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let cleanedCommand = root.query.replace("file://", "");
                cleanedCommand = StringUtils.cleanPrefix(cleanedCommand, Config.options.search.prefix.shellCommand);
                if (cleanedCommand.startsWith(Config.options.search.prefix.shellCommand)) {
                    cleanedCommand = cleanedCommand.slice(Config.options.search.prefix.shellCommand.length);
                }
                Quickshell.execDetached(["bash", "-c", cleanedCommand.startsWith("sudo") ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
            }
        };
    }

    function webSearchResult() {
        return {
            key: "web-search",
            name: StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch),
            verb: Translation.tr("Search"),
            type: Translation.tr("Web search"),
            iconName: "travel_explore",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let query = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.webSearch);
                let url = Config.options.search.engineBaseUrl + query;
                for (let site of Config.options.search.excludedSites) {
                    url += ` -site:${site}`;
                }
                Qt.openUrlExternally(url);
            }
        };
    }

    function launcherActionResult(action) {
        const actionString = `${Config.options.search.prefix.action}${action.action}`;
        const isPartialMatch = actionString.startsWith(root.query);
        const isExecutableMatch = root.query === actionString || root.query.startsWith(`${actionString} `);
        if (!isPartialMatch && !isExecutableMatch) return null;
        return {
            key: `action:${action.action}`,
            name: root.query.startsWith(actionString) ? root.query : actionString,
            verb: Translation.tr("Run"),
            type: Translation.tr("Action"),
            iconName: "settings_suggest",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                const args = root.query.startsWith(`${actionString} `) ? root.query.slice(actionString.length).trimStart() : "";
                action.execute(args);
            }
        };
    }

    Timer {
        id: nonAppResultsTimer
        interval: Config.options.search.nonAppResultDelay
        onTriggered: {
            const expr = root.mathExpression(root.query);
            if (expr.length === 0) return;
            mathProc.calculateExpression(expr);
        }
    }

    Timer {
        id: fileSearchTimer
        property string expression: ""
        interval: Math.max(Config.options.search.nonAppResultDelay, 150)
        onTriggered: fileProc.searchFiles(expression)
    }

    onQueryChanged: updateNonAppSearches()

    Process {
        id: mathProc
        property list<string> baseCommand: ["qalc", "-t"]
        property string activeExpression: ""
        function calculateExpression(expression) {
            mathProc.running = false;
            mathProc.activeExpression = expression;
            mathProc.command = baseCommand.concat(expression);
            mathProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                if (root.mathExpression(root.query) !== mathProc.activeExpression) return;
                root.mathResult = data;
            }
        }
    }

    property var fileResults: []
    Process {
        id: fileProc 
        property string activeExpression: ""
        function searchFiles(expr) {
            if (expr.length < 2) return
            activeExpression = expr;
            fileProc.running = false;
            fileProc.command = ["fd", "--", expr, Config.options.search.fileSearchDirectory];
            fileProc.running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const currentExpr = root.hasPrefix(Config.options.search.prefix.fileSearch)
                    ? root.query.slice(Config.options.search.prefix.fileSearch.length).trim()
                    : "";
                if (currentExpr !== fileProc.activeExpression) return;
                const rawResult = this.text
                const result = rawResult.split('\n')
                result.pop() // deleting the last empty line
                root.fileResults = result
            }
        }

    }

    property list<var> results: {
        // Search results are handled here
        ////////////////// Skip? //////////////////
        if (root.query == "")
            return [];

        ///////////// Special cases ///////////////
        if (root.hasPrefix(Config.options.search.prefix.clipboard)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.clipboard);
            return Cliphist.fuzzyQuery(searchString).map((entry, index, array) => root.clipboardResult(entry, index, array));
        } else if (root.hasPrefix(Config.options.search.prefix.emojis)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.emojis);
            return Emojis.fuzzyQuery(searchString).map(entry => root.emojiResult(entry));
        } else if (root.hasPrefix(Config.options.search.prefix.window)) {
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.window).trim();
            return root.windowResults(searchString).map(entry => root.windowResult(entry));
        }

        //////// Prioritized by prefix /////////
        let result = [];
        const startsWithNumber = /^\d/.test(root.query);
        const startsWithActionPrefix = root.hasPrefix(Config.options.search.prefix.action);
        const startsWithAppPrefix = root.hasPrefix(Config.options.search.prefix.app);
        const startsWithFileSearchPrefix = root.hasPrefix(Config.options.search.prefix.fileSearch);
        const startsWithMathPrefix = root.hasPrefix(Config.options.search.prefix.math);
        const startsWithShellCommandPrefix = root.hasPrefix(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = root.hasPrefix(Config.options.search.prefix.webSearch);
        const startsWithWindowPrefix = root.hasPrefix(Config.options.search.prefix.window);
        if ((startsWithNumber || startsWithMathPrefix) && root.mathResult.length > 0) {
            result.push(root.mathResultEntry());
        } else if (startsWithShellCommandPrefix) {
            result.push(root.commandResult());
        } else if (startsWithWebSearchPrefix) {
            result.push(root.webSearchResult());
        }

        //////////////// Files /////////////////
        if (startsWithFileSearchPrefix) {
            result = result.concat(root.fileResults.map(entry => root.fileResult(entry)));
        }

        //////////////// Apps //////////////////
        const shouldSearchApps = !startsWithActionPrefix && !startsWithFileSearchPrefix && !startsWithMathPrefix && !startsWithShellCommandPrefix && !startsWithWebSearchPrefix && !startsWithWindowPrefix && !startsWithNumber;
        if (shouldSearchApps || startsWithAppPrefix) {
            result = result.concat(AppSearch.fuzzyQuery(StringUtils.cleanPrefix(root.query, Config.options.search.prefix.app), root.resultLimit).map(entry => root.appResult(entry)));
        }

        ////////// Launcher actions ////////////
        if (startsWithActionPrefix) {
            result = result.concat(root.allActions.map(action => root.launcherActionResult(action)).filter(Boolean));
        }

        /// Math result, command, web search ///
        if (Config.options.search.prefix.showDefaultActionsWithoutPrefix) {
            if (!startsWithShellCommandPrefix)
                result.push(root.commandResult());
            if (!startsWithNumber && !startsWithMathPrefix && root.mathResult.length > 0)
                result.push(root.mathResultEntry());
            if (!startsWithWebSearchPrefix)
                result.push(root.webSearchResult());
        }

        return result;
    }
}
