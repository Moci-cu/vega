pragma Singleton

import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

Singleton {
    id: root

    property string query: ""
    property int resultLimit: 15

    signal wifiPanelRequested()
    signal bluetoothPanelRequested()
    signal timerPanelRequested()
    signal todoPanelRequested()

    readonly property list<var> searchPrefixEntries: [
        { name: "action", prefix: Config.options.search.prefix.action },
        { name: "app", prefix: Config.options.search.prefix.app },
        { name: "clipboard", prefix: Config.options.search.prefix.clipboard },
        { name: "emojis", prefix: Config.options.search.prefix.emojis },
        { name: "math", prefix: Config.options.search.prefix.math },
        { name: "shellCommand", prefix: Config.options.search.prefix.shellCommand },
        { name: "webSearch", prefix: Config.options.search.prefix.webSearch },
        { name: "fileSearch", prefix: Config.options.search.prefix.fileSearch },
        { name: "window", prefix: Config.options.search.prefix.window }
    ]

    function matchedPrefixEntry(queryText = root.query) {
        const queryString = String(queryText ?? "");
        let match = null;
        for (const entry of root.searchPrefixEntries) {
            if (!entry.prefix || !queryString.startsWith(entry.prefix)) continue;
            if (!match || entry.prefix.length > match.prefix.length) match = entry;
        }
        return match;
    }

    function matchedPrefixName(queryText = root.query) {
        return root.matchedPrefixEntry(queryText)?.name ?? "";
    }

    function matchedPrefix(queryText = root.query) {
        return root.matchedPrefixEntry(queryText)?.prefix ?? "";
    }

    function isImplicitMathQuery(queryText = root.query) {
        return /^[+-]?\d/.test(String(queryText ?? "").trim());
    }

    function isApplicationQuery(queryText = root.query) {
        const queryString = String(queryText ?? "");
        if (root.isImplicitMathQuery(queryString))
            return false;
        if (root.isWifiCommandQuery(queryString))
            return false;
        if (root.naturalCommandResult(queryString))
            return false;
        const prefixName = root.matchedPrefixName(queryString);
        return prefixName === "app" || prefixName === "";
    }

    function isWifiCommandQuery(queryText = root.query) {
        return /^wi-?fi$/i.test(String(queryText ?? "").trim());
    }

    readonly property list<var> commandKeywords: [
        {
            key: "wifi",
            name: "wifi",
            aliases: ["wifi", "wireless"],
            verb: Translation.tr("Commands"),
            iconName: "wifi",
            keepLauncherOpen: true,
            execute: () => root.query = "wifi"
        },
        {
            key: "timer",
            name: "Timer",
            aliases: ["timer", "countdown"],
            verb: Translation.tr("Open"),
            iconName: "timer",
            keepLauncherOpen: true,
            execute: () => root.timerPanelRequested()
        },
        {
            key: "todo",
            name: "To-Do",
            aliases: ["todo", "task", "tasks"],
            verb: Translation.tr("Open"),
            iconName: "checklist",
            keepLauncherOpen: true,
            execute: () => root.todoPanelRequested()
        },
        {
            key: "night-mode",
            name: "Night Mode",
            aliases: ["nightmode", "nightlight"],
            verb: Hyprsunset.temperatureActive ? Translation.tr("Turn Off") : Translation.tr("Turn On"),
            iconName: Config.options.light.night.automatic ? "night_sight_auto" : "bedtime",
            execute: () => Hyprsunset.toggleTemperature()
        },
        {
            key: "coffee-mode",
            name: "Coffee Mode",
            aliases: ["coffeemode", "coffemode", "coffee", "keepawake", "caffeine"],
            verb: Idle.inhibit ? Translation.tr("Turn Off") : Translation.tr("Turn On"),
            iconName: Idle.inhibit ? "kettle" : "coffee",
            execute: () => Idle.toggleInhibit()
        }
    ]

    readonly property list<var> naturalIntents: [
        { key: "open", aliases: ["open", "show", "scan", "manage"] },
        { key: "on", aliases: ["enable", "on", "start", "activate", "aktifkan", "nyalakan"] },
        { key: "off", aliases: ["disable", "off", "stop", "deactivate", "matikan", "nonaktifkan"] }
    ]
    readonly property list<var> naturalTargets: [
        { key: "wifi", aliases: ["wifi", "wireless", "wlan"] },
        { key: "bluetooth", aliases: ["bluetooth", "bt"] },
        { key: "timer", aliases: ["timer", "countdown"] },
        { key: "todo", aliases: ["todo", "task", "tasks"] }
    ]
    readonly property list<string> naturalFillers: [
        "turn", "please", "the", "my", "device", "devices", "network", "networks", "radio", "now", "tolong"
    ]
    readonly property list<var> powerProfileChoices: [
        {
            key: "power-saver",
            completion: "saver",
            name: Translation.tr("Power Saver"),
            iconName: "energy_savings_leaf",
            value: PowerProfile.PowerSaver
        },
        {
            key: "balanced",
            completion: "balanced",
            name: Translation.tr("Balanced"),
            iconName: "airwave",
            value: PowerProfile.Balanced
        },
        {
            key: "performance",
            completion: "performance",
            name: Translation.tr("Performance"),
            iconName: "local_fire_department",
            value: PowerProfile.Performance
        }
    ]

    readonly property list<var> naturalCommands: [
        {
            key: "wifi-open",
            intent: "open",
            target: "wifi",
            name: "Open Wi-Fi",
            verb: Translation.tr("Open"),
            iconName: "wifi_find",
            keepLauncherOpen: true,
            execute: () => root.wifiPanelRequested()
        },
        {
            key: "wifi-on",
            intent: "on",
            target: "wifi",
            name: "Enable Wi-Fi",
            verb: Translation.tr("Turn On"),
            iconName: "wifi",
            execute: () => Quickshell.execDetached(["nmcli", "radio", "wifi", "on"])
        },
        {
            key: "wifi-off",
            intent: "off",
            target: "wifi",
            name: "Disable Wi-Fi",
            verb: Translation.tr("Turn Off"),
            iconName: "signal_wifi_off",
            execute: () => Quickshell.execDetached(["nmcli", "radio", "wifi", "off"])
        },
        {
            key: "bluetooth-open",
            intent: "open",
            target: "bluetooth",
            name: "Open Bluetooth",
            verb: Translation.tr("Open"),
            iconName: "bluetooth_searching",
            keepLauncherOpen: true,
            execute: () => root.bluetoothPanelRequested()
        },
        {
            key: "bluetooth-on",
            intent: "on",
            target: "bluetooth",
            name: "Enable Bluetooth",
            verb: Translation.tr("Turn On"),
            iconName: "bluetooth",
            execute: () => {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = true;
            }
        },
        {
            key: "bluetooth-off",
            intent: "off",
            target: "bluetooth",
            name: "Disable Bluetooth",
            verb: Translation.tr("Turn Off"),
            iconName: "bluetooth_disabled",
            execute: () => {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = false;
            }
        },
        {
            key: "timer-open",
            intent: "open",
            target: "timer",
            name: "Open Timer",
            verb: Translation.tr("Open"),
            iconName: "timer",
            keepLauncherOpen: true,
            execute: () => root.timerPanelRequested()
        },
        {
            key: "todo-open",
            intent: "open",
            target: "todo",
            name: "Open To-Do",
            verb: Translation.tr("Open"),
            iconName: "checklist",
            keepLauncherOpen: true,
            execute: () => root.todoPanelRequested()
        }
    ]

    function compactKeyword(text) {
        return String(text ?? "").trim().toLowerCase().replace(/[\s-]/g, "");
    }

    function naturalTokens(text) {
        const normalized = String(text ?? "").toLowerCase()
            .replace(/wi[^a-z0-9]*fi/g, "wifi")
            .replace(/blue[^a-z0-9]*tooth/g, "bluetooth");
        return normalized.match(/[a-z0-9]+/g) ?? [];
    }

    function naturalTokenScore(token, alias) {
        if (token === alias)
            return 1;
        if (alias.startsWith(token))
            return 0.82 + Math.min(0.16, token.length / alias.length * 0.16);
        if (token.length < 2 || alias.length < 2)
            return 0;
        return Levendist.computeScore(token, alias);
    }

    function naturalGroupMatch(tokens, groups) {
        let best = null;
        let runnerUpScore = 0;
        for (const group of groups) {
            let groupMatch = { key: group.key, score: 0, tokenIndex: -1, alias: "", exact: false, prefix: false };
            for (let tokenIndex = 0; tokenIndex < tokens.length; ++tokenIndex) {
                for (const alias of group.aliases) {
                    const score = root.naturalTokenScore(tokens[tokenIndex], alias);
                    if (score <= groupMatch.score)
                        continue;
                    groupMatch = {
                        key: group.key,
                        score: score,
                        tokenIndex: tokenIndex,
                        alias: alias,
                        exact: tokens[tokenIndex] === alias,
                        prefix: alias.startsWith(tokens[tokenIndex])
                    };
                }
            }
            if (!best || groupMatch.score > best.score) {
                runnerUpScore = best?.score ?? 0;
                best = groupMatch;
            } else {
                runnerUpScore = Math.max(runnerUpScore, groupMatch.score);
            }
        }
        return best?.score >= 0.74 && best.score - runnerUpScore >= 0.06 ? best : null;
    }

    function keywordResult(command, compactQuery, completeOnly = undefined, completionName = undefined) {
        return {
            key: `command-keyword:${command.key}`,
            name: command.name,
            completionName: completionName ?? command.name,
            verb: command.verb,
            type: Translation.tr("Action"),
            iconName: command.iconName,
            iconType: LauncherSearchResult.IconType.Material,
            completeOnly: completeOnly ?? !(command.aliases ?? []).includes(compactQuery),
            keepLauncherOpen: command.keepLauncherOpen === true,
            execute: command.execute
        };
    }

    function timerCommandResult(queryText = root.query) {
        const queryString = String(queryText ?? "");
        const prefixEntry = root.matchedPrefixEntry(queryString);
        if (prefixEntry && prefixEntry.name !== "action")
            return null;
        const timerText = (prefixEntry ? queryString.slice(prefixEntry.prefix.length) : queryString)
            .trim().toLowerCase().replace(/[.!?]+$/, "");
        const timerStarter = ["set", "start"].find(starter => timerText === starter
            || timerText.startsWith(`${starter} `));
        if (timerStarter) {
            const guidedText = [`${timerStarter} timer for`, `${timerStarter} a timer for`,
                `${timerStarter} countdown for`].find(text => text.startsWith(timerText));
            if (guidedText)
                return root.keywordResult({
                    key: "timer-guide",
                    name: Translation.tr("Set Timer"),
                    verb: Translation.tr("Set"),
                    iconName: "timer",
                    keepLauncherOpen: true,
                    execute: () => root.timerPanelRequested()
                }, root.compactKeyword(timerText), true,
                    `${prefixEntry?.prefix ?? ""}${guidedText}`);
        }
        const match = timerText.match(/^(?:(?:set|start)\s+)?(?:a\s+)?(?:timer|countdown)(?:\s+(?:for|to))?\s+(\d+)(?:\s*(m|min(?:ute)?s?|h|hrs?|hours?))?$/);
        if (!match)
            return null;
        const amount = Number(match[1]);
        const unit = match[2] ?? "minutes";
        const minutes = unit.startsWith("h") ? amount * 60 : amount;
        if (minutes < 1 || minutes > 1440)
            return null;
        const completionName = match[2] ? queryString.trim()
            : `${queryString.trim()} ${amount === 1 ? "minute" : "minutes"}`;
        const result = root.keywordResult({
            key: "timer-set",
            name: Translation.tr("%1 minute timer").arg(minutes),
            verb: Translation.tr("Start"),
            iconName: "timer",
            keepLauncherOpen: true,
            execute: () => {
                if (TimerService.startPomodoroMinutes(minutes))
                    root.timerPanelRequested();
            }
        }, root.compactKeyword(timerText), false, completionName);
        result.durationMinutes = minutes;
        return result;
    }

    function todoCommandResult(queryText = root.query) {
        const queryString = String(queryText ?? "");
        const prefixEntry = root.matchedPrefixEntry(queryString);
        if (prefixEntry && prefixEntry.name !== "action")
            return null;
        const todoText = (prefixEntry ? queryString.slice(prefixEntry.prefix.length) : queryString)
            .trim().toLowerCase().replace(/[.!?]+$/, "");
        const starter = ["add", "create"].find(verb => todoText === verb
            || todoText.startsWith(`${verb} `));
        if (starter) {
            const guidedText = [`${starter} task`, `${starter} a task`, `${starter} todo`]
                .find(text => text.startsWith(todoText));
            if (guidedText)
                return root.keywordResult({
                    key: "todo-guide",
                    name: Translation.tr("Add Task"),
                    verb: Translation.tr("Add"),
                    iconName: "add_task",
                    keepLauncherOpen: true,
                    execute: () => root.todoPanelRequested()
                }, root.compactKeyword(todoText), true,
                    `${prefixEntry?.prefix ?? ""}${guidedText}`);
        }
        const match = todoText.match(/^(?:add|create)\s+(?:a\s+)?(?:task|todo)(?:\s+(?:to|for))?\s+(.+)$/);
        if (!match)
            return null;
        const description = match[1].trim();
        if (!description)
            return null;
        const result = root.keywordResult({
            key: "todo-add",
            name: Translation.tr("Add “%1”").arg(description),
            verb: Translation.tr("Add"),
            iconName: "add_task",
            keepLauncherOpen: true,
            execute: () => {
                Todo.addTask(description);
                root.todoPanelRequested();
            }
        }, root.compactKeyword(todoText), false, queryString.trim());
        result.taskDescription = description;
        return result;
    }

    function powerProfileCommandResult(queryText = root.query) {
        const queryString = String(queryText ?? "");
        const prefixEntry = root.matchedPrefixEntry(queryString);
        if (prefixEntry && prefixEntry.name !== "action")
            return null;
        const powerText = (prefixEntry ? queryString.slice(prefixEntry.prefix.length) : queryString)
            .trim().toLowerCase().replace(/[.!?]+$/, "");
        const choice = root.powerProfileChoices.find(entry => {
            const command = `${entry.completion} mode`;
            return (powerText.length >= 4 && entry.completion.startsWith(powerText))
                || (powerText.startsWith(`${entry.completion} `) && command.startsWith(powerText));
        });
        if (!choice || (choice.key === "performance" && !PowerProfiles.hasPerformanceProfile))
            return null;
        const result = root.keywordResult({
            key: `power-profile-${choice.key}`,
            name: Translation.tr("Set power profile to %1").arg(choice.name),
            verb: Translation.tr("Set"),
            iconName: choice.iconName,
            execute: () => PowerProfiles.profile = choice.value
        }, root.compactKeyword(powerText), powerText !== `${choice.completion} mode`,
            `${prefixEntry?.prefix ?? ""}${choice.completion} mode`);
        result.powerProfile = choice.key;
        return result;
    }

    function naturalCommandResult(queryText = root.query) {
        const timerCommand = root.timerCommandResult(queryText);
        if (timerCommand)
            return timerCommand;
        const todoCommand = root.todoCommandResult(queryText);
        if (todoCommand)
            return todoCommand;
        const queryString = String(queryText ?? "");
        const prefixEntry = root.matchedPrefixEntry(queryString);
        if (prefixEntry && prefixEntry.name !== "action")
            return null;
        const naturalText = prefixEntry ? queryString.slice(prefixEntry.prefix.length) : queryString;
        const tokens = root.naturalTokens(naturalText);
        if (tokens.length === 0)
            return null;
        const intent = root.naturalGroupMatch(tokens, root.naturalIntents);
        const target = root.naturalGroupMatch(tokens, root.naturalTargets);
        const hasUnknownToken = tokens.some((token, index) => index !== intent?.tokenIndex
            && index !== target?.tokenIndex && !root.naturalFillers.includes(token));

        if (!intent) {
            if (target?.key !== "wifi" || root.isWifiCommandQuery(queryString) || hasUnknownToken)
                return null;
            const wifiCommand = root.commandKeywords.find(command => command.key === "wifi");
            return wifiCommand ? root.keywordResult(wifiCommand, root.compactKeyword(naturalText),
                !target.exact, prefixEntry ? `${prefixEntry.prefix}wifi` : "wifi") : null;
        }
        if (hasUnknownToken || (!target && !intent.prefix))
            return null;

        const candidates = root.naturalCommands.filter(command => command.intent === intent.key
            && (!target || command.target === target.key));
        if (candidates.length === 0)
            return null;
        let command = candidates[0];
        for (let index = 1; index < candidates.length; ++index) {
            if (AppSearch.launcherUsageBonus(`command-keyword:${candidates[index].key}`)
                    > AppSearch.launcherUsageBonus(`command-keyword:${command.key}`))
                command = candidates[index];
        }
        const completedTokens = tokens.slice();
        completedTokens[intent.tokenIndex] = intent.alias;
        if (target)
            completedTokens[target.tokenIndex] = command.target;
        else
            completedTokens.push(command.target);
        const completionName = `${prefixEntry?.prefix ?? ""}${completedTokens.join(" ")}`;
        return root.keywordResult(command, root.compactKeyword(naturalText),
            !target || !intent.exact || !target.exact, completionName);
    }

    function commandKeywordResult(queryText = root.query) {
        const compactQuery = root.compactKeyword(queryText);
        if (!compactQuery)
            return null;
        const powerProfileCommand = root.powerProfileCommandResult(queryText);
        if (powerProfileCommand)
            return powerProfileCommand;
        const naturalCommand = root.naturalCommandResult(queryText);
        if (naturalCommand)
            return naturalCommand;
        if (root.isWifiCommandQuery(queryText))
            return null;
        const command = root.commandKeywords.find(entry => entry.aliases.some(
            alias => alias.startsWith(compactQuery)));
        if (!command)
            return null;
        const completionName = command.name.toLowerCase().startsWith(String(queryText).trim().toLowerCase())
            ? command.name : command.aliases.find(alias => alias.startsWith(compactQuery));
        return root.keywordResult(command, compactQuery, undefined, completionName);
    }

    function appAutocompleteCompletion(entry, queryText) {
        const query = root.nativeAppQuery(queryText).trim().toLowerCase();
        const name = String(entry?.name ?? "");
        const foldedName = name.toLowerCase();
        if (!query || !name)
            return null;
        if (foldedName.startsWith(query))
            return name.slice(query.length);
        const containedAt = foldedName.indexOf(query);
        if (containedAt >= 0)
            return name.slice(containedAt + query.length) || ` → ${name}`;

        const queryWords = root.naturalTokens(query);
        const nameWords = root.naturalTokens(name);
        let nextWord = 0;
        for (const queryWord of queryWords) {
            while (nextWord < nameWords.length && !nameWords[nextWord].startsWith(queryWord))
                ++nextWord;
            if (nextWord >= nameWords.length)
                return null;
            ++nextWord;
        }
        return queryWords.length > 0 ? ` → ${name}` : null;
    }

    function preferredAutocomplete(queryText, appEntry) {
        const actionEntry = root.commandKeywordResult(queryText);
        if (!actionEntry) return appEntry;
        if (!actionEntry.completeOnly) return actionEntry;
        if (!appEntry) return actionEntry;
        const query = String(queryText ?? "").trim().toLowerCase().replace(/[\s-]/g, "");
        const appName = String(appEntry.name ?? "").trim().toLowerCase().replace(/[\s-]/g, "");
        if (!appName.startsWith(query)) return actionEntry;
        return AppSearch.launcherUsageBonus(appEntry.key) >= AppSearch.launcherUsageBonus(actionEntry.key)
            ? appEntry : actionEntry;
    }

    function shouldUseNativeAppSearch(queryText = root.query) {
        if (!NativeAppSearch.available || AppSearch.sloppySearch || Config.options.panelFamily !== "ii")
            return false;
        return root.isApplicationQuery(queryText);
    }

    function nativeAppQuery(queryText = root.query) {
        return StringUtils.cleanPrefix(String(queryText ?? ""), Config.options.search.prefix.app);
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
    ]

    readonly property list<var> wifiCommandActions: [
        {
            name: Translation.tr("Scan Wi-Fi Networks"),
            iconName: "wifi_find",
            verb: Translation.tr("Open"),
            keepLauncherOpen: true,
            execute: () => root.wifiPanelRequested()
        },
        {
            name: Translation.tr("Turn Wi-Fi Off"),
            iconName: "signal_wifi_off",
            verb: Translation.tr("Run"),
            execute: () => Quickshell.execDetached(["nmcli", "radio", "wifi", "off"])
        },
        {
            name: Translation.tr("Turn Wi-Fi On"),
            iconName: "wifi",
            verb: Translation.tr("Run"),
            execute: () => Quickshell.execDetached(["nmcli", "radio", "wifi", "on"])
        },
        {
            name: Translation.tr("Restart Wi-Fi"),
            iconName: "restart_alt",
            verb: Translation.tr("Run"),
            execute: () => Quickshell.execDetached([
                "sh", "-c", "nmcli radio wifi off && nmcli radio wifi on"
            ])
        }
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
        const prefixName = root.matchedPrefixName(query);
        if (prefixName === "math") {
            return query.slice(Config.options.search.prefix.math.length).trim();
        }
        if (prefixName === "" && root.isImplicitMathQuery(query)) {
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

        if (root.matchedPrefixName(query) !== "fileSearch") {
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

    function resolvedResult(entry) {
        if (!entry) return null;
        if (entry.nativeApp) {
            const app = AppSearch.entryById(entry.id);
            return app ? root.appResult(app) : null;
        }
        if (entry.nativeFallback)
            return root.results.find(result => result.key === entry.key) ?? null;
        return entry;
    }

    function executeResult(entry) {
        const resolved = root.resolvedResult(entry);
        if (!resolved?.execute) return;
        const key = String(entry?.key ?? resolved.key ?? "");
        AppSearch.recordLauncherUse(key.startsWith("wifi-command:")
            ? "command-keyword:wifi" : key);
        resolved.execute();
    }

    function keepsOverviewOpen(entry) {
        return root.resolvedResult(entry)?.keepLauncherOpen === true;
    }

    function resultActions(entry, limit) {
        entry = root.resolvedResult(entry);
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

    function wifiCommandResult(action, index) {
        return {
            key: `wifi-command:${index}`,
            name: action.name,
            verb: action.verb,
            type: Translation.tr("Wi-Fi Command"),
            iconName: action.iconName,
            iconType: LauncherSearchResult.IconType.Material,
            keepLauncherOpen: action.keepLauncherOpen === true,
            execute: action.execute
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
            fileProc.command = ["fd", "--fixed-strings", "--max-results", root.resultLimit.toString(), "--", expr, Config.options.search.fileSearchDirectory];
            fileProc.running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const currentExpr = root.matchedPrefixName() === "fileSearch"
                    ? root.query.slice(Config.options.search.prefix.fileSearch.length).trim()
                    : "";
                if (currentExpr !== fileProc.activeExpression) return;
                root.fileResults = this.text.split('\n').filter(path => path.length > 0);
            }
        }

    }

    property list<var> results: {
        // Search results are handled here
        ////////////////// Skip? //////////////////
        if (root.query == "")
            return [];

        const naturalCommand = root.naturalCommandResult();

        if (root.isWifiCommandQuery())
            return root.wifiCommandActions.map((action, index) => root.wifiCommandResult(action, index));

        ///////////// Special cases ///////////////
        const prefixName = root.matchedPrefixName();
        if (prefixName === "clipboard") {
            if (Config.options.panelFamily === "ii")
                return [];
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.clipboard);
            return Cliphist.fuzzyQuery(searchString).map((entry, index, array) => root.clipboardResult(entry, index, array));
        } else if (prefixName === "emojis") {
            // Clipboard
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.emojis);
            return Emojis.fuzzyQuery(searchString).map(entry => root.emojiResult(entry));
        } else if (prefixName === "window") {
            const searchString = StringUtils.cleanPrefix(root.query, Config.options.search.prefix.window).trim();
            return root.windowResults(searchString).map(entry => root.windowResult(entry));
        }

        //////// Prioritized by prefix /////////
        let result = [];
        if (naturalCommand)
            result.push(naturalCommand);
        const implicitMathQuery = root.isImplicitMathQuery(root.query);
        const startsWithActionPrefix = prefixName === "action";
        const startsWithAppPrefix = prefixName === "app";
        const startsWithFileSearchPrefix = prefixName === "fileSearch";
        const startsWithMathPrefix = prefixName === "math";
        const startsWithShellCommandPrefix = prefixName === "shellCommand";
        const startsWithWebSearchPrefix = prefixName === "webSearch";
        const startsWithWindowPrefix = prefixName === "window";
        if (implicitMathQuery || startsWithMathPrefix) {
            if (Config.options.panelFamily === "ii")
                return root.mathResult.length > 0 ? [root.mathResultEntry()] : [];
            if (root.mathResult.length > 0)
                result.push(root.mathResultEntry());
        }
        if (startsWithShellCommandPrefix) {
            result.push(root.commandResult());
        } else if (startsWithWebSearchPrefix) {
            result.push(root.webSearchResult());
        }

        //////////////// Files /////////////////
        if (startsWithFileSearchPrefix) {
            result = result.concat(root.fileResults.map(entry => root.fileResult(entry)));
        }

        //////////////// Apps //////////////////
        const shouldSearchApps = !startsWithActionPrefix && !startsWithFileSearchPrefix && !startsWithMathPrefix && !startsWithShellCommandPrefix && !startsWithWebSearchPrefix && !startsWithWindowPrefix && !implicitMathQuery;
        if ((shouldSearchApps || startsWithAppPrefix) && !root.shouldUseNativeAppSearch(root.query)) {
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
            if (!implicitMathQuery && !startsWithMathPrefix && root.mathResult.length > 0)
                result.push(root.mathResultEntry());
            if (!startsWithWebSearchPrefix)
                result.push(root.webSearchResult());
        }

        return result;
    }
}
