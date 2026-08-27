import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: notificationPopup

    PanelWindow {
        id: root
        readonly property bool forceMonitorEnabled: Config.options.notifications?.monitor?.enable ?? false
        readonly property string forceMonitorName: Config.options.notifications?.monitor?.name ?? ""

        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked
        screen: Quickshell.screens.find(s => root.forceMonitorEnabled ? s.name === root.forceMonitorName : s.name === Hyprland.focusedMonitor?.name) ?? null

        WlrLayershell.namespace: "quickshell:notificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: 0

        anchors {
            top: true
            right: true
            bottom: true
        }

        mask: Region {
            item: listview.contentItem
        }

        color: "transparent"
        implicitWidth: Appearance.sizes.notificationPopupWidth

        Item {
            id: notificationGlassTarget
            anchors {
                top: parent.top
                right: parent.right
                rightMargin: 4
                topMargin: 4
            }
            width: listview.width
            height: Math.max(1, Math.min(listview.contentHeight, root.height - anchors.topMargin))
        }

        LiquidGlassCapture {
            id: notificationGlassCapture
            screen: root.screen
            target: notificationGlassTarget
            active: root.visible
            windowOriginX: Math.max(0, (screen?.width ?? root.width) - root.width)
        }

        NotificationListView {
            id: listview
            glassCapture: notificationGlassCapture
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                rightMargin: 4
                topMargin: 4
            }
            implicitWidth: parent.width - Appearance.sizes.elevationMargin * 2
            popup: true
        }
    }
}
