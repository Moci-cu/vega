import Qt5Compat.GraphicalEffects
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Services.Mpris

// Shows Genius lyrics in a scrollable, syncable view. Syncing is based on the current position of the track and the total length, so it's not perfect but it's something.

Item {
    id: root

    property var player: MprisController.activePlayer
    property string geniusLyricsString: LyricsService.geniusHasLyrics ? LyricsService.plainLyrics : ""

    property bool hasSyncedLines: LyricsService.syncedLines.length > 0
    readonly property real playerLength: {
        if (!root.player?.lengthSupported)
            return 0

        const length = Number(root.player?.length ?? 0)
        return isFinite(length) && length > 0 ? length : 0
    }
    readonly property real playerPosition: {
        const position = Number(root.player?.position ?? 0)
        return isFinite(position) ? Math.max(0, position) : 0
    }

    Timer {
        running: root.player?.playbackState == MprisPlaybackState.Playing
            && !root.hasSyncedLines
            && LyricsService.geniusHasLyrics
            && root.playerLength > 0
        interval: 250
        repeat: true
        onTriggered: {
            if (root.player)
                root.player.positionChanged()
        }
    }

    MaterialLoadingIndicator {
        anchors.left: parent.left
        anchors.leftMargin: 250
        anchors.verticalCenter: parent.verticalCenter
        loading: geniusFlickable.opacity == 0 && !hasSyncedLines
        visible: loading
        implicitSize: 96
    }

    Flickable {
        id: geniusFlickable
        anchors.fill: parent
        
        opacity: !hasSyncedLines && LyricsService.geniusHasLyrics ? 1 : 0
        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        

        clip: true
        contentHeight: geniusText.implicitHeight
        interactive: true

        property bool isSyncing: true

        readonly property real rawTargetY: {
            if (!root.player || root.playerLength <= 0 || root.geniusLyricsString.trim().length === 0)
                return 0

            const progress = Math.max(0, Math.min(1, root.playerPosition / root.playerLength))
            const maxContentY = Math.max(0, contentHeight - height)
            const targetY = progress * contentHeight - height / 2
            return Math.max(0, Math.min(maxContentY, targetY))
        }

        property real userScrollOffset: Persistent.states.background.mediaMode.userScrollOffset
        onUserScrollOffsetChanged: {
            updateScrolling()
        }

        onMovementEnded: {
            Persistent.states.background.mediaMode.userScrollOffset = contentY - rawTargetY
            isSyncing = true 
        }

        onMovementStarted: isSyncing = false

        onRawTargetYChanged: {
            updateScrolling()
        }

        function updateScrolling() {
            if (!isSyncing || dragging || flicking)
                return

            const maxContentY = Math.max(0, contentHeight - height)
            const targetY = rawTargetY + Persistent.states.background.mediaMode.userScrollOffset
            contentY = Math.max(0, Math.min(maxContentY, targetY))
        }

        Behavior on contentY {
            enabled: geniusFlickable.isSyncing
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: geniusFlickable.width
                    height: geniusFlickable.height
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.3; color: "black" }
                        GradientStop { position: 0.7; color: "black" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }


        StyledText {
            id: geniusText
            width: parent.width
            text: root.geniusLyricsString
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.hugeass * 1.2
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignTop
            lineHeight: 1.6
        }
    }
}
