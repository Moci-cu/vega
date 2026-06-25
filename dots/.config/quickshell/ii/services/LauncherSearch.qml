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
    property int resultLimit: 20

    function ensurePrefix(prefix) {
        if ([Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch, Config.options.search.prefix.fileSearch].some(i => root.query.startsWith(i))) {
            root.query = prefix + root.query.slice(1);
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
        if (query.startsWith(Config.options.search.prefix.math)) {
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
            nonAppResultsTimer.restart();
        } else {
            nonAppResultsTimer.stop();
            mathProc.running = false;
            root.mathResult = "";
        }

        if (!query.startsWith(Config.options.search.prefix.fileSearch)) {
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

    function resultActions(entry) {
        if (!entry) return [];
        const actions = entry.actions;
        if (typeof actions === "function") return actions();
        return actions ?? [];
    }

    function clipboardResult(entry, index, array) {
        const mightBlurImage = Cliphist.entryIsImage(entry) && root.clipboardWorkSafetyActive;
        let shouldBlurImage = mightBlurImage;
        if (mightBlurImage) {
            shouldBlurImage = shouldBlurImage && (root.containsUnsafeLink(array[index - 1]) || root.containsUnsafeLink(array[index + 1]));
        }
        const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`;
        return {
            rawValue: entry,
            name: StringUtils.cleanCliphistEntry(entry),
            verb: "",
            type: type,
            execute: () => Cliphist.copy(entry),
            actions: () => [
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
            ],
            blurImage: shouldBlurImage
        };
    }

    function emojiResult(entry) {
        const emoji = entry.match(/^\s*(\S+)/)?.[1] || "";
        return {
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
            actions: () => entry.actions.map(action => root.appAction(action))
        };
    }

    function commandResult() {
        return {
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
                Quickshell.execDetached(["bash", "-c", root.query.startsWith("sudo") ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
            }
        };
    }

    function webSearchResult() {
        return {
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
        if (!actionString.startsWith(root.query) && !root.query.startsWith(actionString)) return null;
        return {
            name: root.query.startsWith(actionString) ? root.query : actionString,
            verb: Translation.tr("Run"),
            type: Translation.tr("Action"),
            iconName: "settings_suggest",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                action.execute(root.query.split(" ").slice(1).join(" "));
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
        function calculateExpression(expression) {
            mathProc.running = false;
            mathProc.command = baseCommand.concat(expression);
            mathProc.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
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
            fileProc.command = ["fd", expr, Config.options.search.fileSearchDirectory]; 
            fileProc.running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const currentExpr = root.query.startsWith(Config.options.search.prefix.fileSearch)
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
        if (root.query.startsWith(Config.options.search.prefix.clipboard)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.clipboard);
            return Cliphist.fuzzyQuery(searchString).map((entry, index, array) => root.clipboardResult(entry, index, array));
        } else if (root.query.startsWith(Config.options.search.prefix.emojis)) {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.emojis);
            return Emojis.fuzzyQuery(searchString).map(entry => root.emojiResult(entry));
        }

        //////// Prioritized by prefix /////////
        let result = [];
        const startsWithNumber = /^\d/.test(root.query);
        const startsWithActionPrefix = root.query.startsWith(Config.options.search.prefix.action);
        const startsWithAppPrefix = root.query.startsWith(Config.options.search.prefix.app);
        const startsWithFileSearchPrefix = root.query.startsWith(Config.options.search.prefix.fileSearch);
        const startsWithMathPrefix = root.query.startsWith(Config.options.search.prefix.math);
        const startsWithShellCommandPrefix = root.query.startsWith(Config.options.search.prefix.shellCommand);
        const startsWithWebSearchPrefix = root.query.startsWith(Config.options.search.prefix.webSearch);
        if (startsWithNumber || startsWithMathPrefix) {
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
        const shouldSearchApps = !startsWithActionPrefix && !startsWithFileSearchPrefix && !startsWithMathPrefix && !startsWithShellCommandPrefix && !startsWithWebSearchPrefix && !startsWithNumber;
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
            if (!startsWithNumber && !startsWithMathPrefix)
                result.push(root.mathResultEntry());
            if (!startsWithWebSearchPrefix)
                result.push(root.webSearchResult());
        }

        return result;
    }
}
