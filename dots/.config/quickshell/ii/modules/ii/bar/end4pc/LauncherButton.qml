// Adapted from pctrade/end4-pC (GPL-3.0); see README.md.
import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: true

    implicitWidth: 22
    implicitHeight: 22
    Accessible.name: Translation.tr("Launcher")

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colPrimaryContainer : "transparent"
    colBackgroundHover: isMaterial ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: isMaterial ? Appearance.colors.colLayer1Active : Appearance.colors.colLayer1Active
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.overviewOpen

    downAction: () => {
        GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
    }

    MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 18
        text: "search"
        color: Appearance.colors.colOnLayer0
    }
}
