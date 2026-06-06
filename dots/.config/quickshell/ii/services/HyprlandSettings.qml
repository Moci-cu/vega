pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    signal reloaded()

    function changeKey(key, value) {
        if (/['"\\`$|&;]/.test(String(value)) || /['"\\`$|&;]/.test(String(key))) {
            console.error("[HyprlandSettings] Unsafe characters rejected:", key, value)
            return
        }
        if (!key.includes(":")) return
        Quickshell.execDetached([Directories.cliPath, "hyprset", "key", key, String(value)])
    }

    function changeAnimation(animName, style) {
        if (/['"\\`$|&;]/.test(String(animName)) || /['"\\`$|&;]/.test(String(style))) {
            console.error("[HyprlandSettings] Unsafe characters rejected:", animName, style)
            return
        }
        Quickshell.execDetached([Directories.cliPath, "hyprset", "anim", animName, String(style)])
    }

    function setLayout(layout) {
        if (layout !== "default" && layout !== "scrolling" && layout !== "dwindle" && layout !== "monocle" && layout !== "master") return
        // console.log("[HyprlandSettings] Setting layout to", layout)
        changeKey("general:layout", layout)
        Persistent.states.hyprland.layout = layout
    }

    function setRounding(rounding) {
        changeKey("decoration:rounding", rounding)
    }

    //NOTE: We use bash -c cmd1 && cmd2 && cmd ..... to prevent race condition on setKeys and resetKeys

    function setKeys(entries) {
        var parts = []
        var keys = Object.keys(entries)
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i]
            var value = entries[key]
            if (/['"\\`$|&;]/.test(String(value)) || /['"\\`$|&;]/.test(String(key))) {
                console.error("[HyprlandSettings] Unsafe characters rejected:", key, value)
                continue
            }
            if (!key.includes(":")) continue
            parts.push(Directories.cliPath + " hyprset key " + key + " " + String(value))
        }
        if (parts.length > 0)
            Quickshell.execDetached(["bash", "-c", parts.join(" && ")])
    }

    function reset(key) {
        if (/['"\\`$|&;]/.test(String(key))) {
            console.error("[HyprlandSettings] Unsafe characters rejected:", key)
            return
        }
        Quickshell.execDetached([Directories.cliPath, "hyprset", "reset", key])
    }

    function resetKeys(keys) {
        var parts = []
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i]
            if (/['"\\`$|&;]/.test(String(key))) {
                console.error("[HyprlandSettings] Unsafe characters rejected:", key)
                continue
            }
            parts.push(Directories.cliPath + " hyprset reset " + key)
        }
        if (parts.length > 0)
            Quickshell.execDetached(["bash", "-c", parts.join(" && ")])
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                root.reloaded()
            }
        }
    }
}
