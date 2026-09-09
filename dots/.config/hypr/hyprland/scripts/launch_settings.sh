#!/usr/bin/env bash

set -u

config_name="${qsConfig:-ii}"
config_path="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/${config_name}/settings.qml"
page="${1:-}"

open_existing() {
    qs -p "$config_path" ipc call settings open "$page" >/dev/null 2>&1
}

launch_output=$(II_SETTINGS_PAGE="$page" qs -n -d -p "$config_path" 2>&1)
launch_status=$?

if [[ "$launch_output" == *"already running"* ]]; then
    for _ in {1..20}; do
        if open_existing; then
            exit 0
        fi
        sleep 0.05
    done
    exit 1
fi

if [ "$launch_status" -eq 0 ]; then
    exit 0
fi

if [ "$page" = "wifi" ] && command -v kcmshell6 >/dev/null 2>&1; then
    exec kcmshell6 kcm_networkmanagement
fi
if command -v systemsettings >/dev/null 2>&1; then
    exec systemsettings
fi
if command -v gnome-control-center >/dev/null 2>&1; then
    exec gnome-control-center
fi

exit 1
