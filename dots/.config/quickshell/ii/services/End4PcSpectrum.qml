pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root
    property int users: 0
    property list<real> points: []
    property var player: MprisController.activePlayer
    readonly property bool wanted: users > 0 && Config.ready && !GlobalStates.screenLocked && (player?.isPlaying ?? false)
    readonly property bool running: process.running
    property string error: ""

    function parseFrame(line) {
        return line.split(";").filter(value => value.trim().length > 0).map(Number)
            .filter(Number.isFinite).map(value => Math.max(0, Math.min(1000, value)));
    }

    Process {
        id: process
        running: root.wanted
        command: ["cava", "-p", FileUtils.trimFileProtocol(Directories.scriptPath) + "/cava/raw_output_config.txt"]
        onRunningChanged: {
            root.points = [];
            if (running) root.error = "";
        }
        stdout: SplitParser { onRead: data => root.points = root.parseFrame(data) }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) root.error = text.trim(); } }
        onExited: code => {
            root.points = [];
            if (code !== 0 && root.wanted) {
                root.error = "Cava exited with code " + code;
                console.warn("[End4PcSpectrum]", root.error);
            }
        }
    }
}
