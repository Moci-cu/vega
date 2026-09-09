pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root
    property int activeInstances: 0
    property bool available: false
    readonly property int paws: (leftHold.running ? 1 : 0) | (rightHold.running ? 2 : 0)

    function tap(bits) {
        if (bits & 1) leftHold.restart();
        if (bits & 2) rightHold.restart();
    }

    Timer { id: leftHold; interval: 100 }
    Timer { id: rightHold; interval: 100 }

    Process {
        running: root.activeInstances > 0 && !GlobalStates.screenLocked
        command: ["python3", "-u", Quickshell.shellPath("scripts/bongocat-input.py")]
        stdout: SplitParser {
            onRead: data => {
                if (data === "ready" || data === "unavailable")
                    root.available = data === "ready";
                else if (data === "1" || data === "2" || data === "3")
                    root.tap(Number(data));
            }
        }
        onRunningChanged: {
            if (!running) {
                root.available = false;
                leftHold.stop();
                rightHold.stop();
            }
        }
    }
}
