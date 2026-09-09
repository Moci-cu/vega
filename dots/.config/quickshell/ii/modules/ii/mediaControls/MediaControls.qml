pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool visible: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var realPlayers: MprisController.players
    readonly property var meaningfulPlayers: filterDuplicatePlayers(realPlayers)
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
    property list<real> visualizerPoints: []
    property bool surfaceShown: GlobalStates.mediaControlsOpen
    property bool contentLoaded: GlobalStates.mediaControlsOpen

    function filterDuplicatePlayers(players) {
        let filtered = [];
        let used = new Set();

        for (let i = 0; i < players.length; ++i) {
            if (used.has(i))
                continue;
            let p1 = players[i];
            let group = [i];

            // Find duplicates by trackTitle prefix
            for (let j = i + 1; j < players.length; ++j) {
                let p2 = players[j];
                if (p1.trackTitle && p2.trackTitle && (p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle)) || (p1.position - p2.position <= 2 && p1.length - p2.length <= 2)) {
                    group.push(j);
                }
            }

            // Pick the one with non-empty trackArtUrl, or fallback to the first
            let chosenIdx = group.find(idx => players[idx].trackArtUrl && players[idx].trackArtUrl.length > 0);
            if (chosenIdx === undefined)
                chosenIdx = group[0];

            filtered.push(players[chosenIdx]);
            group.forEach(idx => used.add(idx));
        }
        return filtered;
    }

    Process {
        id: cavaProc
        running: GlobalStates.mediaControlsOpen
        onRunningChanged: {
            if (!cavaProc.running) {
                root.visualizerPoints = [];
            }
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                // Parse `;`-separated values into the visualizerPoints array
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.visualizerPoints = points;
            }
        }
    }

    Connections {
        target: GlobalStates
        function onMediaControlsOpenChanged() {
            if (GlobalStates.mediaControlsOpen) {
                mediaUnloadTimer.stop();
                root.contentLoaded = true;
                Qt.callLater(() => {
                    if (GlobalStates.mediaControlsOpen)
                        root.surfaceShown = true;
                });
                return;
            }

            root.surfaceShown = false;
            mediaUnloadTimer.restart();
        }
    }

    Loader {
        id: mediaControlsLoader
        active: root.contentLoaded
        onActiveChanged: {
            if (!mediaControlsLoader.active && root.realPlayers.length === 0) {
                GlobalStates.mediaControlsOpen = false;
            }
        }

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            implicitWidth: root.widgetWidth
            implicitHeight: playerColumnLayout.implicitHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mediaControls"
            
            readonly property var rect: Persistent.states.media.popupRect ?? Qt.rect(0, 0, 0, 0)
            readonly property real barThickness: {
                if (Config.options.bar.vertical) {
                    return Config.options.bar.sizes.width || 40;
                } else {
                    return Config.options.bar.sizes.height || 40;
                }
            }
            anchors {
                top: true
                left: !Config.options.bar.vertical || !Config.options.bar.bottom
                right: Config.options.bar.vertical && Config.options.bar.bottom
            }
            margins {
                top: {
                    if (rect.width === 0) return 0;
                    if (Config.options.bar.vertical) {
                        let targetY = rect.y + (rect.height / 2) - (panelWindow.implicitHeight / 2);
                        return Math.max(0, Math.min(targetY, screen.height - panelWindow.implicitHeight));
                    } else {
                        if (!Config.options.bar.bottom) {
                            return barThickness;
                        } else {
                            return screen.height - barThickness - panelWindow.implicitHeight;
                        }
                    }
                }
                left: {
                    if (rect.width === 0) return 0;
                    if (Config.options.bar.vertical) {
                        if (!Config.options.bar.bottom) {
                            return barThickness;
                        }
                        return 0;
                    } else {
                        let targetX = rect.x + (rect.width / 2) - (panelWindow.implicitWidth / 2);
                        return Math.max(0, Math.min(targetX, screen.width - panelWindow.implicitWidth));
                    }
                }
                right: {
                    if (rect.width === 0) return 0;
                    if (Config.options.bar.vertical && Config.options.bar.bottom) {
                        return barThickness;
                    }
                    return 0;
                }
            }

            mask: Region {
                item: GlobalStates.mediaControlsOpen ? playerColumnLayout : null
            }

            Component.onCompleted: {
                if (GlobalStates.mediaControlsOpen)
                    GlobalFocusGrab.addDismissable(panelWindow);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Connections {
                target: GlobalStates
                function onMediaControlsOpenChanged() {
                    if (GlobalStates.mediaControlsOpen)
                        GlobalFocusGrab.addDismissable(panelWindow);
                    else
                        GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.mediaControlsOpen = false;
                }
            }

            ColumnLayout {
                id: playerColumnLayout
                anchors.fill: parent
                spacing: -Appearance.sizes.elevationMargin // Shadow overlap okay

                transform: Translate {
                    x: {
                        if (root.surfaceShown || !Config.options.bar.vertical)
                            return 0;
                        return Config.options.bar.bottom ? playerColumnLayout.width : -playerColumnLayout.width;
                    }
                    y: {
                        if (root.surfaceShown || Config.options.bar.vertical)
                            return 0;
                        return Config.options.bar.bottom ? playerColumnLayout.height : -playerColumnLayout.height;
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: root.surfaceShown ? Appearance.animation.elementMoveEnter.duration : Appearance.animation.elementMoveExit.duration
                            easing.type: root.surfaceShown ? Appearance.animation.elementMoveEnter.type : Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: root.surfaceShown ? Appearance.animation.elementMoveEnter.bezierCurve : Appearance.animation.elementMoveExit.bezierCurve
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: root.surfaceShown ? Appearance.animation.elementMoveEnter.duration : Appearance.animation.elementMoveExit.duration
                            easing.type: root.surfaceShown ? Appearance.animation.elementMoveEnter.type : Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: root.surfaceShown ? Appearance.animation.elementMoveEnter.bezierCurve : Appearance.animation.elementMoveExit.bezierCurve
                        }
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: root.meaningfulPlayers
                    }
                    delegate: PlayerControl {
                        required property MprisPlayer modelData
                        player: modelData
                        visualizerPoints: root.visualizerPoints
                        implicitWidth: root.widgetWidth
                        implicitHeight: root.widgetHeight
                        radius: root.popupRounding
                    }
                }

                Item {
                    // No player placeholder
                    Layout.alignment: {
                        if (panelWindow.anchors.left)
                            return Qt.AlignLeft;
                        if (panelWindow.anchors.right)
                            return Qt.AlignRight;
                        return Qt.AlignHCenter;
                    }
                    Layout.leftMargin: Appearance.sizes.hyprlandGapsOut
                    Layout.rightMargin: Appearance.sizes.hyprlandGapsOut
                    visible: root.meaningfulPlayers.length === 0
                    implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
                    implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

                    StyledRectangularShadow {
                        target: placeholderBackground
                    }

                    Rectangle {
                        id: placeholderBackground
                        anchors.centerIn: parent
                        color: Appearance.colors.colGlassSurface
                        radius: root.popupRounding
                        property real padding: 20
                        implicitWidth: placeholderLayout.implicitWidth + padding * 2
                        implicitHeight: placeholderLayout.implicitHeight + padding * 2

                        ColumnLayout {
                            id: placeholderLayout
                            anchors.centerIn: parent

                            StyledText {
                                text: Translation.tr("No active player")
                                font.pixelSize: Appearance.font.pixelSize.large
                            }
                            StyledText {
                                color: Appearance.colors.colSubtext
                                text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: mediaUnloadTimer
        interval: Appearance.animation.elementMoveExit.duration
        onTriggered: {
            if (!GlobalStates.mediaControlsOpen)
                root.contentLoaded = false;
        }
    }

    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            if (GlobalStates.mediaControlsOpen)
                Notifications.timeoutAll();
        }

        function close(): void {
            GlobalStates.mediaControlsOpen = false;
        }

        function open(): void {
            GlobalStates.mediaControlsOpen = true;
            Notifications.timeoutAll();
        }
    }

    GlobalShortcut {
        name: "mediaControlsToggle"
        description: "Toggles media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
        }
    }
    GlobalShortcut {
        name: "mediaControlsOpen"
        description: "Opens media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = true;
        }
    }
    GlobalShortcut {
        name: "mediaControlsClose"
        description: "Closes media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = false;
        }
    }
}
