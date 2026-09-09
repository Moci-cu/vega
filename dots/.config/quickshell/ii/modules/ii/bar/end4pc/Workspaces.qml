// end4-pC's 30px workspace slots, circular app icons and trailing indicator;
// workspace IDs and dispatches use Vega's Hyprland Lua configuration.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: false
    property var screen: root.QsWindow.window?.screen
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property int monitorIndex: Math.max(0, HyprlandData.monitors.findIndex(m => m.name === root.screen?.name))
    readonly property int offset: Config.options.bar.workspaces.useWorkspaceMap ? (Config.options.bar.workspaces.workspaceMap[monitorIndex] ?? 0) : 0
    readonly property int count: Math.max(1, Config.options.bar.workspaces.shown)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? offset + 1
    readonly property int group: Math.max(0, Math.floor((activeId - offset - 1) / count))
    readonly property var ids: Array.from({length: count}, (_, i) => offset + group * count + i + 1)
        .filter(id => !Config.options.bar.workspaces.dynamicWorkspaces || id === activeId || HyprlandData.windowList.some(w => w.workspace.id === id))
    readonly property int activeIndex: Math.max(0, ids.indexOf(activeId))
    property bool showNumbers: false
    implicitWidth: vertical ? 32 : row.implicitWidth
    implicitHeight: vertical ? row.implicitHeight : 40

    Timer { id: held; interval: Config.options.bar.workspaces.showNumberDelay; onTriggered: root.showNumbers = true }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (GlobalStates.superDown) held.restart();
            else { held.stop(); root.showNumbers = false; }
        }
    }
    function focusWorkspace(id) {
        if (!Number.isInteger(id) || id < 1) return;
        Hyprland.dispatch("hl.dsp.focus({workspace = " + id + "})");
    }

    AnimatedTabIndexPair { id: pair; index: root.activeIndex }
    Rectangle {
        x: root.vertical ? 3 : Math.min(pair.idx1, pair.idx2) * 30 + 2
        y: root.vertical ? Math.min(pair.idx1, pair.idx2) * 30 + 2 : 7
        width: root.vertical ? 26 : Math.abs(pair.idx1 - pair.idx2) * 30 + 26
        height: root.vertical ? Math.abs(pair.idx1 - pair.idx2) * 30 + 26 : 26
        radius: 13
        color: Appearance.colors.colPrimary
        opacity: Config.options.bar.workspaces.activeIndicatorOpacity / 100
    }
    GridLayout {
        id: row
        anchors.centerIn: parent
        columns: root.vertical ? 1 : -1
        rowSpacing: 0
        columnSpacing: 0
        Repeater {
            model: root.ids
            delegate: MouseArea {
                id: slot
                required property int modelData
                readonly property var largest: {
                    HyprlandData.windowList;
                    return HyprlandData.biggestWindowForWorkspace(modelData);
                }
                readonly property bool showIcon: !!largest && Config.options.bar.workspaces.showAppIcons && !root.showNumbers
                readonly property bool numbered: root.showNumbers || (Config.options.bar.workspaces.alwaysShowNumbers && !showIcon)
                width: 30
                height: 30
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.RightButton) GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                    else root.focusWorkspace(modelData);
                }
                onWheel: event => {
                    if (event.angleDelta.y === 0) return;
                    Hyprland.dispatch(event.angleDelta.y < 0 ? 'hl.dsp.focus({workspace = "r+1"})' : 'hl.dsp.focus({workspace = "r-1"})');
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 26; height: 26; radius: 13
                    color: Appearance.colors.colSecondaryContainer
                    opacity: slot.containsMouse ? 0.6 : (slot.largest && slot.modelData !== root.activeId ? 0.4 : 0)
                }
                Image {
                    id: icon
                    anchors.centerIn: parent
                    width: 21; height: 21
                    sourceSize: Qt.size(42, 42)
                    visible: slot.showIcon
                    source: slot.largest ? Quickshell.iconPath(AppSearch.guessIcon(slot.largest.class), "image-missing") : ""
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: Rectangle { width: 21; height: 21; radius: 11 } }
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: !slot.showIcon
                    text: slot.numbered ? (Config.options.bar.workspaces.numberMap[slot.modelData - 1] || slot.modelData) : "•"
                    font.pixelSize: slot.numbered ? 12 : 16
                    color: slot.modelData === root.activeId ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    opacity: slot.numbered || slot.largest ? 1 : 0.45
                }
                PopupToolTip {
                    text: Translation.tr("Workspace") + " " + slot.modelData
                    extraVisibleCondition: slot.containsMouse
                }
            }
        }
    }
}
