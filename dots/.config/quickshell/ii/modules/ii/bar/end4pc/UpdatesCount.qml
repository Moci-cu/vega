import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root
    implicitWidth: row.implicitWidth + 4
    implicitHeight: 24
    buttonRadius: 12
    Accessible.name: Translation.tr("Check for updates")
    downAction: () => Updates.refresh()
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4
        MaterialSymbol { text: "deployed_code"; iconSize: 20; color: Appearance.colors.colOnPrimaryContainer }
        StyledText { text: Updates.checking ? "…" : Updates.count; font.pixelSize: 12; color: Appearance.colors.colOnPrimaryContainer }
    }
    Timer { id: tooltipDelay; interval: 500; running: root.hovered; onTriggered: tooltip.extraVisibleCondition = true }
    onHoveredChanged: if (!hovered) tooltip.extraVisibleCondition = false
    PopupToolTip {
        id: tooltip
        text: Translation.tr("Check for updates")
        extraVisibleCondition: false
        anchorEdges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
        anchorGravity: anchorEdges
    }
}
