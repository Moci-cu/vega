import QtQuick
import Quickshell
import qs.services
import qs.modules.ii.bar

ShellRoot {
    property int phase: 0
    BongoCatWidget { id: cat; visible: false }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            const images = cat.children.filter(child => child instanceof Image);
            if (images.length !== 4 || images.some(image => image.status !== Image.Ready)) {
                console.error("FAIL: Bongo Cat SVG loading");
                Qt.exit(1);
                return;
            }
            if (BongoCat.activeInstances !== 0 || BongoCat.paws !== 0) {
                console.error("FAIL: hidden widget capture or paw timeout");
                Qt.exit(1);
                return;
            }
            if (phase === 3) {
                console.log("PASS: Bongo Cat QML, left/right/both taps and idle reset");
                Qt.exit(0);
                return;
            }
            const expected = ++phase;
            BongoCat.tap(expected);
            if (BongoCat.paws !== expected) {
                console.error("FAIL: paw frame mapping");
                Qt.exit(1);
            }
        }
    }
}
