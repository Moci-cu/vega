pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.modules.common
import qs.modules.common.widgets

GridLayout {
    id: root
    property bool vertical: false
    columns: vertical ? 1 : -1
    rowSpacing: 3
    columnSpacing: 3
    Repeater {
        model: SystemTray.items
        delegate: RippleButton {
            id: button
            required property SystemTrayItem modelData
            implicitWidth: 26
            implicitHeight: 26
            buttonRadius: 13
            Accessible.name: modelData.title || modelData.id
            downAction: () => {
                if (modelData.onlyMenu) menu.open();
                else modelData.activate();
            }
            altAction: () => menu.open()
            middleClickAction: () => modelData.secondaryActivate()
            IconImage { anchors.centerIn: parent; implicitSize: 20; source: button.modelData.icon }
            QsMenuAnchor {
                id: menu
                menu: button.modelData.menu
                anchor.item: button
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y !== 0) button.modelData.scroll(event.angleDelta.y / 120, false);
                    else if (event.angleDelta.x !== 0) button.modelData.scroll(event.angleDelta.x / 120, true);
                }
            }
            PopupToolTip { text: button.modelData.tooltipTitle || button.modelData.title || button.modelData.id }
        }
    }
}
