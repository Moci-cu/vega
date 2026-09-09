# end4-pC Material bar for Vega

Port of the Material bar in https://github.com/pctrade/end4-pC,
snapshot `5e84d8c5a106dd752af64d60b8f3033723c5e893`, GPL-3.0 (see LICENSE).
Upstream authors retain copyright. Adapted components retain their original
geometry, media controls, dock interactions and visualizer rendering.

Enable in Settings > Bar > end4-pC Material bar. This replaces horizontal bar
content; Vega retains its screen selection, autohide and lock lifecycle.
Top, bottom, left and right positions use the same Material layout.
Settings > Bar provides add/remove/drag ordering for all three sections,
including Vega components. Visualizers may be added more than once.

The reference preset uses `bar.end4pc.left`, `center`, and `right` arrays:

- left: launcherButton, workspaces, media
- center: visualizer, docktoPanel, visualizer
- right: sysTray, powerButton, systemIcons, resources, batteryIndicator, updatesCount

`clockWidget` can also be placed in these arrays. Empty tray and absent battery
are omitted. Unknown names are ignored instead of loading arbitrary QML paths.
Colors follow Vega's wallpaper palette; installed app icons and live metadata
come from this machine. Dock pins use the existing `dock.pinnedApps` setting.

Vega integration: native MPRIS artwork loading (no shell downloader), capability
checks for transport controls, Vega media/power/sidebar/popups, Hyprland Lua
workspace dispatch, existing TaskbarApps and ResourceUsage services, and one
reference-counted Cava process shared by bar visualizers across screens.

Run the functional check from the repo root:

    qs -p dots/.config/quickshell/ii/end4PcBarCheck.qml

This checks loading, sizes, MPRIS capability routing with a fake player, actual
Cava frames, lock stopping and listener release. It does not judge appearance.
