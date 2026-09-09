// Material layout adapted from pctrade/end4-pC (GPL-3.0). See README.md.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.common
import qs.modules.ii.bar as Vega

Item {
    id: root
    property bool vertical: false
    property int monitorIndex: 0
    property var leftLayout: Config.options.bar.end4pc.left
    property var centerLayout: Config.options.bar.end4pc.center
    property var rightLayout: Config.options.bar.end4pc.right
    implicitHeight: 40
    implicitWidth: 56
    readonly property var screen: root.QsWindow.window?.screen
    readonly property real length: vertical ? height : width
    readonly property real requiredLength: start.extent + middle.extent + end.extent + 32
    readonly property real fit: Math.min(1, length / Math.max(1, requiredLength))

    function nativeWidget(name) { return BarComponentRegistry.end4pcComponents.some(c => c.id === name); }
    function filterLayout(names) {
        return names.filter(name => BarComponentRegistry.end4pcCatalog.some(c => c.id === name)
            && (name !== "sysTray" || SystemTray.items.values.length > 0)
            && (name !== "batteryIndicator" || Battery.available));
    }
    function pillColor(name) {
        if (name === "resources") return "transparent";
        if (name === "media" || name === "sysTray") return Appearance.colors.colSecondaryContainer;
        if (name === "systemIcons") return Appearance.colors.colPrimary;
        return Appearance.colors.colPrimaryContainer;
    }

    component Section: Rectangle {
        id: section
        required property var widgets
        property real position: 5
        readonly property real extent: root.vertical ? height : width
        implicitWidth: row.implicitWidth + 10
        implicitHeight: root.vertical ? row.implicitHeight + 10 : 40
        width: implicitWidth
        height: implicitHeight
        x: root.vertical ? (root.width - width) / 2 : position
        y: root.vertical ? position : (root.height - height) / 2
        scale: root.fit
        transformOrigin: root.vertical ? Item.Top : Item.Left
        radius: Math.min(width, height) / 2
        color: Appearance.colors.colLayer0
        visible: widgets.length > 0

        GridLayout {
            id: row
            anchors.centerIn: parent
            columns: root.vertical ? 1 : -1
            rowSpacing: 3
            columnSpacing: 3
            Repeater {
                model: section.widgets
                delegate: Rectangle {
                    id: group
                    required property string modelData
                    required property int index
                    readonly property bool isPcWidget: root.nativeWidget(modelData)
                    readonly property bool painted: isPcWidget && !["workspaces", "launcherButton", "powerButton", "docktoPanel", "resources"].includes(modelData)
                    visible: widget.item?.visible !== false
                    implicitWidth: root.vertical ? Math.max(32, widget.implicitWidth + (painted ? 10 : 0)) : widget.implicitWidth + (painted ? 10 : 0)
                    implicitHeight: root.vertical ? widget.implicitHeight + (painted ? 10 : 0) : 32
                    radius: Math.min(width, height) / 2
                    color: painted ? root.pillColor(modelData) : "transparent"
                    Loader {
                        id: widget
                        anchors.centerIn: parent
                        sourceComponent: group.isPcWidget ? Qt.createComponent(Qt.resolvedUrl(group.modelData.charAt(0).toUpperCase() + group.modelData.slice(1) + ".qml")) : legacyWidget
                        onLoaded: {
                            if ("vertical" in item) item.vertical = Qt.binding(() => root.vertical);
                            if (group.modelData === "visualizer")
                                item.mirrored = section.widgets.slice(0, group.index).filter(name => name === "visualizer").length % 2 === 1;
                            if ("screen" in item) item.screen = Qt.binding(() => root.screen);
                        }
                    }
                    Component {
                        id: legacyWidget
                        Vega.BarComponent {
                            modelData: ({id: group.modelData, visible: true})
                            index: 0
                            barSection: 1
                            list: [modelData]
                            vertical: root.vertical
                            persistVisibility: false
                            colBackground: "transparent"
                            screen: root.screen
                        }
                    }
                }
            }
        }
    }
    Section {
        id: start
        widgets: root.filterLayout(root.leftLayout)
    }
    Section {
        id: middle
        widgets: root.filterLayout(root.centerLayout)
        position: Math.max(start.extent * root.fit + 11, Math.min((root.length - extent * root.fit) / 2, root.length - 11 - (end.extent + extent) * root.fit))
    }
    Section {
        id: end
        widgets: root.filterLayout(root.rightLayout)
        position: root.length - extent * root.fit - 5
    }
}
