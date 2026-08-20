pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    property MprisPlayer player
    property int interval: 1000
    property bool running: false
    property int requestId: -1

    function syncRequest() {
        if (root.requestId < 0) return;
        MprisController.updatePositionTicker(root.requestId, root.player, root.interval, root.running);
    }

    Component.onCompleted: {
        root.requestId = MprisController.registerPositionTicker(root.player, root.interval, root.running);
    }
    Component.onDestruction: MprisController.unregisterPositionTicker(root.requestId)

    onPlayerChanged: root.syncRequest()
    onIntervalChanged: root.syncRequest()
    onRunningChanged: root.syncRequest()
}
