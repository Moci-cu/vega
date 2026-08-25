import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    property bool vertical: false
    property color foregroundColor: Appearance.colors.colOnLayer2
    property real containerScreenCenterX: 0
    property var screen
    property real parallaxWorkspaceValue: 0.5
    property real parallaxSidebarBalance: 0
    implicitWidth: gridLayout.implicitWidth + gridLayout.rowSpacing * 2
    implicitHeight: gridLayout.implicitHeight + gridLayout.columnSpacing * 2

    component AdaptiveUtilButton: CircleUtilButton {
        id: button
        required property string symbol
        property real symbolFill: 0
        readonly property real screenCenterX: {
            width;
            x;
            root.width;
            root.containerScreenCenterX;
            let ancestor = parent;
            while (ancestor && ancestor !== root) {
                ancestor.x;
                ancestor.width;
                ancestor = ancestor.parent;
            }
            return root.containerScreenCenterX + mapToItem(root, width / 2, 0).x - root.width / 2;
        }
        readonly property var adaptivePalette: Appearance.colors.transparentBar
            ? Appearance.barPaletteAt(screenCenterX, width, root.screen, root.parallaxWorkspaceValue, root.parallaxSidebarBalance)
            : ({ foreground: root.foregroundColor, haloEnabled: false, haloColor: "transparent" })
        property color adaptiveForeground: adaptivePalette.foreground

        MaterialSymbol {
            horizontalAlignment: Qt.AlignHCenter
            fill: button.symbolFill
            text: button.symbol
            iconSize: Appearance.font.pixelSize.large
            color: button.adaptiveForeground
            haloEnabled: button.adaptivePalette.haloEnabled
            haloColor: button.adaptivePalette.haloColor
        }
    }
    
    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        rows: root.vertical ? -1 : 1

        rowSpacing: 4
        columnSpacing: 4
        anchors.centerIn: parent

        Loader {
            active: Config.options.bar.utilButtons.showScreenSnip
            visible: Config.options.bar.utilButtons.showScreenSnip
            sourceComponent: AdaptiveUtilButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: "screenshot_region"
                symbolFill: 1
                onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showScreenRecord
            visible: Config.options.bar.utilButtons.showScreenRecord
            sourceComponent: AdaptiveUtilButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: "videocam"
                symbolFill: 1
                onClicked: Quickshell.execDetached([Directories.recordScriptPath])
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showColorPicker
            visible: Config.options.bar.utilButtons.showColorPicker
            sourceComponent: AdaptiveUtilButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: "colorize"
                symbolFill: 1
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showKeyboardToggle
            visible: Config.options.bar.utilButtons.showKeyboardToggle
            sourceComponent: AdaptiveUtilButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: "keyboard"
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showMicToggle
            visible: Config.options.bar.utilButtons.showMicToggle
            sourceComponent: AdaptiveUtilButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showDarkModeToggle
            visible: Config.options.bar.utilButtons.showDarkModeToggle
            sourceComponent: AdaptiveUtilButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                onClicked: event => {
                    if (Appearance.m3colors.darkmode) {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`])
                    } else {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`])
                    }
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showPerformanceProfileToggle
            visible: Config.options.bar.utilButtons.showPerformanceProfileToggle
            sourceComponent: AdaptiveUtilButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: switch(PowerProfiles.profile) {
                    case PowerProfile.PowerSaver: return "energy_savings_leaf"
                    case PowerProfile.Balanced: return "airwave"
                    case PowerProfile.Performance: return "local_fire_department"
                }
                onClicked: event => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                            break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                            break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                            break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
            }
        }
    }
}
