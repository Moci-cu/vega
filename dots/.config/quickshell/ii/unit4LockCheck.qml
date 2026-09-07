import QtQuick
import QtMultimedia
import Quickshell
import qs.modules.common.panels.lock
import qs.modules.ii.lock

ShellRoot {
    LockContext { id: context }
    Unit4LockSurface { id: surface; width: 1920; height: 1080; context: context }
    property int ticks: 0
    property bool checkedReveal: false
    function findObject(object, name) {
        if (object.objectName === name) return object;
        for (const child of object.data ?? object.children ?? []) {
            const found = findObject(child, name);
            if (found) return found;
        }
        return null;
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            const reveal = findObject(surface, "unit4Reveal");
            const hide = findObject(surface, "unit4Hide");
            if (!reveal || !hide || reveal.error !== MediaPlayer.NoError || hide.error !== MediaPlayer.NoError) {
                console.error("FAIL: Unit-4 media loading", reveal, hide, reveal?.errorString, hide?.errorString);
                Qt.exit(1);
                return;
            }
            if (++ticks > 100) {
                console.error("FAIL: Unit-4 playback timeout");
                Qt.exit(1);
            }
            if (!checkedReveal && reveal.duration > 0 && reveal.position >= reveal.duration - 50) {
                checkedReveal = true;
                surface.closing = true;
            }
            if (checkedReveal && hide.mediaStatus === MediaPlayer.EndOfMedia) {
                for (const file of ["modules/ii/lock/Lock.qml", "modules/settings/InterfaceConfig.qml"]) {
                    const component = Qt.createComponent(Qt.resolvedUrl(file), Component.PreferSynchronous);
                    if (component.status !== Component.Ready) {
                        console.error("FAIL:", file, component.errorString());
                        Qt.exit(1);
                        return;
                    }
                }
                if (context.authenticationResolved) {
                    console.error("FAIL: animation changed authentication state");
                    Qt.exit(1);
                    return;
                }
                console.log("PASS: Unit-4 QML and both videos; playback cannot authenticate");
                Qt.exit(0);
            }
        }
    }
}
