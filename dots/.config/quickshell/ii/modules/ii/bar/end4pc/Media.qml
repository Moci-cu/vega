// Adapted from pctrade/end4-pC (GPL-3.0); see README.md.
pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.common.models
import qs
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    property bool vertical: false
    property bool borderless: false
    property bool isMaterial: true
    property var activePlayer: MprisController.activePlayer
    function control(action) {
        if (!activePlayer?.canControl) return false;
        if (action === "toggle" && activePlayer.canTogglePlaying) activePlayer.togglePlaying();
        else if (action === "next" && activePlayer.canGoNext) activePlayer.next();
        else if (action === "previous" && activePlayer.canGoPrevious) activePlayer.previous();
        else return false;
        return true;
    }

    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    property var    artUrl:      activePlayer?.trackArtUrl ?? ""
    property string trackTitle:  activePlayer?.trackTitle  ?? ""
    property string trackArtist: activePlayer?.trackArtist ?? ""
    property bool   isPlaying:   activePlayer?.isPlaying   ?? false
    property bool   hasTrack:    trackTitle.length > 0

    readonly property string displayedArtFilePath: String(root.artUrl || "")

    Layout.fillHeight: true
    implicitWidth: vertical
        ? 32
        : (isMaterial
            ? materialRow.implicitWidth
            : Math.max(
                120,
                Math.min(rowLayout.implicitWidth + 8, 300)
            ))
    implicitHeight: vertical ? (isMaterial ? 32 : mediaCircProg.implicitHeight + 12) : 40

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton)      root.control("toggle")
            else if (event.button === Qt.BackButton)   root.control("previous")
            else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) root.control("next")
            else if (event.button === Qt.LeftButton) {
                const pos = root.mapToItem(null, 0, 0);
                Persistent.states.media.popupRect = Qt.rect(pos.x, pos.y, root.width, root.height);
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            }
        }
    }

    // Vertical default
    Loader {
        id: mediaCircProg
        active: root.vertical && !root.isMaterial
        visible: active
        anchors.centerIn: parent
        sourceComponent: ClippedFilledCircularProgress {
            implicitSize: 20
            lineWidth: Appearance.rounding.unsharpen
            value: (root.activePlayer?.length ?? 0) > 0 ? Math.max(0, Math.min(1, root.activePlayer.position / root.activePlayer.length)) : 0
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }
    }

    // Vertical Material
    Rectangle {
        visible: root.vertical && root.isMaterial
        anchors.centerIn: parent
        color: Appearance.colors.colSecondaryContainer
        radius: Appearance.rounding.full
        implicitWidth: 32
        implicitHeight: 32

        MaterialSymbol {
            anchors.centerIn: parent
            fill: 1
            text: root.activePlayer?.isPlaying ? "pause" : "music_note"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnSecondaryContainer
        }
    }

    // Horizontal default
    Loader {
        id: rowLayout
        active: !root.vertical && !root.isMaterial
        visible: active
        anchors.fill: parent
        sourceComponent: RowLayout {
            spacing: 4
            ClippedFilledCircularProgress {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 3
                implicitSize: 20
                lineWidth: Appearance.rounding.unsharpen
                value: root.activePlayer?.position / root.activePlayer?.length
                colPrimary: Appearance.colors.colOnSecondaryContainer
                enableAnimation: false
                Item {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3onSecondaryContainer
                    }
                }
            }
            StyledText {
                visible: Config.options.bar.verbose
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.rightMargin: 0
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer1
                text: false ? root.cleanedTitle : `${root.cleanedTitle}${root.activePlayer?.trackArtist ? ' • ' + root.activePlayer.trackArtist : ''}`
            }
        }
    }

    // Horizontal Material
    Loader {
        id: materialRow
        active: !root.vertical && root.isMaterial
        visible: active
        anchors.centerIn: parent
        sourceComponent: RowLayout {
            id: innerRow
            spacing: 6

            // No platyer
            Loader {
                active: !root.hasTrack
                visible: active
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: RowLayout {
                    spacing: 6

                    // Avatar
                    Rectangle {
                        id: avatarRect
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer
                        Layout.alignment: Qt.AlignVCenter

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarRect.width
                                height: avatarRect.height
                                radius: avatarRect.radius
                            }
                        }

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: Quickshell.iconPath(SystemInfo.distroIcon, "user-identity")
                            sourceSize.width: avatarRect.width * 2
                            sourceSize.height: avatarRect.height * 2
                            fillMode: Image.PreserveAspectCrop
                            onStatusChanged: {
                                if (status === Image.Error)
                                    visible = false
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "account_circle"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                            visible: avatarImage.status === Image.Error || avatarImage.status === Image.Null
                        }
                    }

                    ColumnLayout {
                        spacing: -3
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: 2

                        StyledText {
                            text: SystemInfo.username
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                        }

                        StyledText {
                            id: distroLabel
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                            opacity: 0.7
                            elide: Text.ElideRight
                            Layout.rightMargin: 8
                            Layout.maximumWidth: 120
                            text: SystemInfo.distroName
                        }
                    }
                }
            }

            // Player
            Loader {
                active: root.hasTrack
                visible: active
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: RowLayout {
                    spacing: 6

                    // Art
                    Rectangle {
                        id: artRect
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer
                        Layout.alignment: Qt.AlignVCenter

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: artRect.width
                                height: artRect.height
                                radius: artRect.radius
                            }
                        }

                        StyledImage {
                            anchors.fill: parent
                            source: root.displayedArtFilePath
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            sourceSize.width: artRect.width
                            sourceSize.height: artRect.height
                            visible: root.displayedArtFilePath !== ""
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            fill: 1
                            text: "music_note"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSecondaryContainer
                            visible: root.displayedArtFilePath === ""
                        }
                    }

                    // Title + Artist
                    ColumnLayout {
                        spacing: -4
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: 2

                        StyledText {
                            id: artistText
                            text: root.trackArtist
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                            Behavior on text {
                                SequentialAnimation {
                                    NumberAnimation { target: artistText; property: "x"; to: -artistText.width; duration: 150; easing.type: Easing.InQuad }
                                    PropertyAction { target: artistText; property: "text" }
                                    NumberAnimation { target: artistText; property: "x"; from: artistText.width; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                        StyledText {
                            id: titleText
                            Layout.topMargin: (!root.activePlayer || root.trackArtist.length === 0) ? -13 : 0
                            text: StringUtils.cleanMusicTitle(root.trackTitle) || Translation.tr("No media")
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: Appearance.colors.colOnSecondaryContainer
                            elide: Text.ElideRight
                            opacity: 0.7
                            Layout.maximumWidth: 120
                            Behavior on text {
                                SequentialAnimation {
                                    NumberAnimation { target: titleText; property: "x"; to: -artistText.width; duration: 150; easing.type: Easing.InQuad }
                                    PropertyAction { target: titleText; property: "text" }
                                    NumberAnimation { target: titleText; property: "x"; from: artistText.width; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }

                    // Play/Pause
                    RippleButton {
                        implicitWidth: 40
                        implicitHeight: 23
                        buttonRadius: root.isPlaying ? Appearance.rounding.normal : 13
                        colBackground: root.isPlaying ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerLow
                        colBackgroundHover: root.isPlaying ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover
                        colRipple: root.isPlaying ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive
                        enabled: (root.activePlayer?.canControl && root.activePlayer?.canTogglePlaying) ?? false
                        Accessible.name: root.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")
                        downAction: () => root.control("toggle")
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isPlaying ? "pause" : "play_arrow"
                            iconSize: Appearance.font.pixelSize.large
                            fill: 1
                            color: root.isPlaying ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    // Next
                    RippleButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        Layout.leftMargin: -4
                        buttonRadius: 13
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        enabled: (root.activePlayer?.canControl && (root.activePlayer?.canGoNext || root.activePlayer?.canGoPrevious)) ?? false
                        Accessible.name: Translation.tr("Next track; right-click for previous")
                        downAction: () => root.control("next")
                        altAction: () => root.control("previous")
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            text: "skip_next"
                            iconSize: Appearance.font.pixelSize.large
                            fill: 1
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }
        }
    }
}
