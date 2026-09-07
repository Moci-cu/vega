local home_dir = os.getenv("HOME") or ""
local inherited_qml_import_path = os.getenv("QML_IMPORT_PATH") or ""

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Applications
hl.env("XDG_DATA_DIRS", home_dir .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:$XDG_DATA_DIRS")
local qml_import_path = home_dir .. "/.local/lib/vega/qml"
if inherited_qml_import_path ~= "" then
    qml_import_path = qml_import_path .. ":" .. inherited_qml_import_path
end
hl.env("QML_IMPORT_PATH", qml_import_path)

-- Themes
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Virtual environment
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", home_dir .. "/.local/state/quickshell/.venv")
