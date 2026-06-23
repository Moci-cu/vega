import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root
    required property var entry
    property int iconSize: 24
    readonly property string entryName: root.entry ? root.entry.name : ""
    readonly property string entryIconName: root.entry ? root.entry.iconName : ""
    readonly property int entryIconType: root.entry ? root.entry.iconType : LauncherSearchResult.IconType.None
    readonly property bool systemIcon: root.entryIconType === LauncherSearchResult.IconType.System && root.entryIconName !== ""
    readonly property bool textIcon: root.entryIconType === LauncherSearchResult.IconType.Text
    implicitWidth: Math.max(iconSize, iconLoader.implicitWidth)
    implicitHeight: iconSize

    Loader {
        id: iconLoader
        anchors.centerIn: parent
        active: root.entry !== null
        sourceComponent: root.systemIcon ? systemIconComponent : root.textIcon ? textIconComponent : fallbackIconComponent
    }

    Component {
        id: systemIconComponent
        WAppIcon {
            implicitSize: root.iconSize
            iconName: root.entryIconName
            tryCustomIcon: false
            animated: false
        }
    }

    Component {
        id: textIconComponent
        WText {
            text: root.entryIconName
            font.pixelSize: root.iconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Component {
        id: fallbackIconComponent
        FluentIcon {
            icon: root.entryIconName ? WIcons.fluentFromMaterial(root.entryIconName) : WIcons.guessIconForName(root.entryName)
            implicitSize: root.iconSize
            animated: false
        }
    }
}
