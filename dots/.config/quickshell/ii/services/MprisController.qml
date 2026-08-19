pragma Singleton
pragma ComponentBehavior: Bound

// From https://git.outfoxxed.me/outfoxxed/nixnew
// It does not have a license, but the author is okay with redistribution.

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * A service that provides easy access to the active Mpris player.
 */
Singleton {
	id: root;
	property list<MprisPlayer> allPlayers: Mpris.players.values;
	property list<MprisPlayer> players: Mpris.players.values.filter(player => isRealPlayer(player));
	property MprisPlayer trackedPlayer: null;
	readonly property MprisPlayer preferredPlayer: {
		if (root.priorityPlayer.length === 0) return null;
		return root.players.find(player => player.desktopEntry === root.priorityPlayer) ?? null;
	}
	readonly property MprisPlayer activePlayer: trackedPlayer;
	signal trackChanged(reverse: bool);

	property int nextPositionTickerId: 0;
	property var positionTickerRequests: ({});
	readonly property int positionTickerInterval: {
		let fastestInterval = Infinity;
		for (const request of Object.values(root.positionTickerRequests)) {
			if (!request.running || !request.player) continue;
			fastestInterval = Math.min(fastestInterval, request.interval);
		}
		return Number.isFinite(fastestInterval) ? fastestInterval : 1000;
	}
	readonly property bool positionTickerRunning: Object.values(root.positionTickerRequests)
		.some(request => request.running && request.player);

	property string priorityPlayer: Config.options.media.priorityPlayer;

	property bool __reverse: false;

	property var activeTrack;

	function registerPositionTicker(player, interval, running) {
		const requestId = root.nextPositionTickerId++;
		root.updatePositionTicker(requestId, player, interval, running);
		return requestId;
	}

	function updatePositionTicker(requestId, player, interval, running) {
		if (requestId < 0) return;
		const requests = Object.assign({}, root.positionTickerRequests);
		requests[requestId] = {
			player: player,
			interval: Math.max(16, interval || 1000),
			running: running
		};
		root.positionTickerRequests = requests;
	}

	function unregisterPositionTicker(requestId) {
		if (requestId < 0 || !root.positionTickerRequests[requestId]) return;
		const requests = Object.assign({}, root.positionTickerRequests);
		delete requests[requestId];
		root.positionTickerRequests = requests;
	}

	function updatePlayerPositions() {
		const updatedPlayers = [];
		for (const request of Object.values(root.positionTickerRequests)) {
			if (!request.running || !request.player || updatedPlayers.includes(request.player)) continue;
			updatedPlayers.push(request.player);
			request.player.positionChanged();
		}
	}

	Timer {
		interval: root.positionTickerInterval
		running: root.positionTickerRunning
		repeat: true
		onTriggered: root.updatePlayerPositions()
	}

	function applyPreferredPlayer() {
		if (root.preferredPlayer && root.players.includes(root.preferredPlayer))
			root.trackedPlayer = root.preferredPlayer;
	}

	onPreferredPlayerChanged: {
		if (root.preferredPlayer) Qt.callLater(root.applyPreferredPlayer);
	}

	onPlayersChanged: {
		if (root.trackedPlayer && root.players.includes(root.trackedPlayer)) return;
		root.trackedPlayer = root.preferredPlayer
			?? root.players.find(player => player.isPlaying)
			?? root.players[0]
			?? null;
	}

	property bool hasActivePlasmaIntegration: false
    Process {
        id: plasmaIntegrationAvailabilityCheckProc
        running: true
        command: ["bash", "-c", "command -v plasma-browser-integration-host"]
        onExited: (exitCode, exitStatus) => {
            root.hasActivePlasmaIntegration = (exitCode === 0);
        }
    }
	function isRealPlayer(player) {
        if (!Config.options.media.filterDuplicatePlayers) {
            return true;
        }
        return (
            // Remove native browser buses only if plasma-browser-integration is actually active on D-Bus
            !(root.hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.firefox')) && !(root.hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.chromium')) &&
            // playerctld just copies other buses and we don't need duplicates
            !player.dbusName?.startsWith('org.mpris.MediaPlayer2.playerctld') &&
            // Non-instance mpd bus
            !(player.dbusName?.endsWith('.mpd') && !player.dbusName.endsWith('MediaPlayer2.mpd')));
    }

	// Original stuff from fox below
	Instantiator {
		model: Mpris.players;

		Connections {
			required property MprisPlayer modelData;
			target: modelData;

			Component.onCompleted: {
				if (!root.isRealPlayer(modelData)) return;
				if (root.preferredPlayer) {
					root.trackedPlayer = root.preferredPlayer;
				} else if (root.trackedPlayer == null || modelData.isPlaying) {
					root.trackedPlayer = modelData;
				}
			}

			Component.onDestruction: {
				if (root.trackedPlayer !== modelData) return;
				root.trackedPlayer = root.players.find(player => player !== modelData && player.isPlaying)
					?? root.players.find(player => player !== modelData)
					?? null;
			}

			function onPlaybackStateChanged() {
				if (!modelData.isPlaying || !root.isRealPlayer(modelData))
					return;
				if (root.preferredPlayer && modelData !== root.preferredPlayer) {
					root.trackedPlayer = root.preferredPlayer;
					return;
				}
				if (root.trackedPlayer === modelData) return;
				root.trackedPlayer = modelData;
			}
		}
	}

	Connections {
		target: activePlayer

		function onPostTrackChanged() {
			root.updateTrack();
		}

		function onTrackArtUrlChanged() {
			// console.log("arturl:", activePlayer.trackArtUrl)
			// root.updateTrack();
			if (root.activePlayer.uniqueId == root.activeTrack.uniqueId && root.activePlayer.trackArtUrl != root.activeTrack.artUrl) {
				// cantata likes to send cover updates *BEFORE* updating the track info.
				// as such, art url changes shouldn't be able to break the reverse animation
				const r = root.__reverse;
				root.updateTrack();
				root.__reverse = r;

			}
		}
	}

	onActivePlayerChanged: {
		this.updateTrack();
	}

	function updateTrack() {
		//console.log(`update: ${this.activePlayer?.trackTitle ?? ""} : ${this.activePlayer?.trackArtists}`)
		this.activeTrack = {
			uniqueId: this.activePlayer?.uniqueId ?? 0,
			artUrl: this.activePlayer?.trackArtUrl ?? "",
			title: this.activePlayer?.trackTitle || Translation.tr("Unknown Title"),
			artist: this.activePlayer?.trackArtist || Translation.tr("Unknown Artist"),
			album: this.activePlayer?.trackAlbum || Translation.tr("Unknown Album"),
		};

		this.trackChanged(__reverse);
		this.__reverse = false;
	}

	property bool isPlaying: this.activePlayer && this.activePlayer.isPlaying;
	property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false;
	function togglePlaying() {
		if (this.canTogglePlaying) this.activePlayer.togglePlaying();
	}

	property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false;
	function previous() {
		if (this.canGoPrevious) {
			this.__reverse = true;
			this.activePlayer.previous();
		}
	}

	property bool canGoNext: this.activePlayer?.canGoNext ?? false;
	function next() {
		if (this.canGoNext) {
			this.__reverse = false;
			this.activePlayer.next();
		}
	}

	property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl;

	property bool loopSupported: this.activePlayer && this.activePlayer.loopSupported && this.activePlayer.canControl;
	property var loopState: this.activePlayer?.loopState ?? MprisLoopState.None;
	function setLoopState(loopState: var) {
		if (this.loopSupported) {
			this.activePlayer.loopState = loopState;
		}
	}

	property bool shuffleSupported: this.activePlayer && this.activePlayer.shuffleSupported && this.activePlayer.canControl;
	property bool hasShuffle: this.activePlayer?.shuffle ?? false;
	function setShuffle(shuffle: bool) {
		if (this.shuffleSupported) {
			this.activePlayer.shuffle = shuffle;
		}
	}

	function setActivePlayer(player: MprisPlayer) {
		const targetPlayer = player ?? Mpris.players[0];
		console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`)

		if (targetPlayer && this.activePlayer) {
			this.__reverse = Mpris.players.indexOf(targetPlayer) < Mpris.players.indexOf(this.activePlayer);
		} else {
			// always animate forward if going to null
			this.__reverse = false;
		}

		this.trackedPlayer = targetPlayer;
	}

	IpcHandler {
		target: "mpris"

		function pauseAll(): void {
			for (const player of Mpris.players.values) {
				if (player.canPause) player.pause();
			}
		}

		function playPause(): void { root.togglePlaying(); }
		function previous(): void { root.previous(); }
		function next(): void { root.next(); }
	}
}
