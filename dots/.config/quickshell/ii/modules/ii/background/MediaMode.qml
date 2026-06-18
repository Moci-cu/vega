pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.utils
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item { // MediaMode instance
    id: root

    property MprisPlayer player: MprisController.activePlayer
    property list<real> visualizerPoints: []

    readonly property string trackTitle: root.player.trackTitle || ""
    Component.onCompleted: Persistent.states.background.mediaMode.userScrollOffset = 0
    Component.onDestruction: {
        cavaProc.running = false
    }
    onTrackTitleChanged: Persistent.states.background.mediaMode.userScrollOffset = 0

    property string geniusLyricsString: LyricsService.plainLyrics

    Process {
        id: cavaProc
        running: root.player?.isPlaying ?? false
        onRunningChanged: {
            if (!cavaProc.running) {
                root.visualizerPoints = []
            }
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                const points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
                root.visualizerPoints = points
            }
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: true
        sourceComponent: Item {
            anchors.fill: parent

            Rectangle { // Background
                id: background
                anchors.fill: parent
                color: ColorUtils.applyAlpha(Appearance.colors.colLayer0, 1)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 15

                    MediaModeVisualizerPanel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        player: root.player
                        visualizerPoints: root.visualizerPoints
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Item {
                            id: lyricsItem
                            anchors.fill: parent
                            anchors.leftMargin: -120
                            anchors.rightMargin: 120
                            anchors.topMargin: 40
                            anchors.bottomMargin: 40

                            readonly property bool hasSyncedLines: LyricsService.syncedLines.length > 0
                            readonly property bool geniusEnabled: Config.options.lyricsService.enableGenius
                            readonly property bool lrclibEnabled: Config.options.lyricsService.enableLrclib

                            Component.onCompleted: {
                                if (!geniusEnabled && !lrclibEnabled) return
                                LyricsService.initiliazeLyrics()
                            }

                            FadeLoader {
                                shown: !lyricsItem.hasSyncedLines
                                anchors.fill: parent
                                sourceComponent: LyricsFlickable {
                                    anchors.fill: parent
                                    player: root.player
                                }
                            }
                            
                            FadeLoader {
                                shown: lyricsItem.hasSyncedLines
                                anchors.fill: parent
                                sourceComponent: LyricsSyllable {
                                    anchors.fill: parent
                                    anchors.rightMargin: 100
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MediaModeVisualizerPanel: Item {
        id: panel

        required property var player
        required property list<real> visualizerPoints

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 20

            Rectangle {
                id: visualizerFrame
                Layout.preferredWidth: Math.min(400, parent.width)
                Layout.preferredHeight: 220
                Layout.alignment: Qt.AlignHCenter
                radius: Appearance.rounding.verylarge
                color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.45)
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.colors.colOutline, 0.75)
                clip: true

                WaveVisualizer {
                    anchors.fill: parent
                    anchors.margins: 18
                    points: panel.visualizerPoints
                    live: panel.player?.isPlaying ?? false
                    color: Appearance.colors.colPrimary
                    maxVisualizerValue: 1000
                    smoothing: 2
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: panel.player?.isPlaying ? "graphic_eq" : "music_note"
                    iconSize: 72
                    fill: 1
                    color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.25)
                    visible: panel.visualizerPoints.length < 3 || !(panel.player?.isPlaying ?? false)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: panel.player?.trackArtist || Translation.tr("Unknown Artist")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.family: Appearance.font.family.title
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(panel.player?.trackTitle) || Translation.tr("Unknown Title")
                    font.pixelSize: Appearance.font.pixelSize.hugeass * 1.5
                    font.weight: Font.Bold
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MaterialMusicControls {
                Layout.alignment: Qt.AlignHCenter
                baseButtonHeight: 60
                baseButtonWidth: 60
                player: panel.player
            }

            StyledSlider {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: false
                Layout.preferredWidth: Math.min(360, parent.width)
                Layout.maximumWidth: 360
                implicitWidth: Math.min(360, parent.width)
                enabled: panel.player?.canSeek ?? false
                configuration: StyledSlider.Configuration.Wavy
                highlightColor: Appearance.colors.colPrimary
                trackColor: Appearance.colors.colSecondaryContainer
                handleColor: Appearance.colors.colPrimary
                value: panel.player?.length > 0 ? panel.player.position / panel.player.length : 0
                onMoved: {
                    if (!panel.player || panel.player.length <= 0) return
                    panel.player.position = value * panel.player.length
                }
            }
        }
    }
}
