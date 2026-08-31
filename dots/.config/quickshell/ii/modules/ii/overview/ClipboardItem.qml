import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

RippleButton {
    id: root

    property var entry
    property bool current: false
    property real containerRadius: Appearance.rounding.normal + horizontalMargin
    readonly property string rawValue: entry?.rawValue ?? ""
    readonly property var clipboardPresentation: Cliphist.presentation(rawValue)
    readonly property bool copied: clipboardPresentation.title === Quickshell.clipboardText
        && rawValue.length > 0
    property int horizontalMargin: 10
    property int clipboardHorizontalPadding: 10

    implicitHeight: 58
    buttonRadius: Math.max(0, containerRadius - horizontalMargin)
    colBackground: current ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    colBackgroundHover: Qt.rgba(1, 1, 1, 0.1)
    colRipple: Qt.rgba(1, 1, 1, 0.16)

    background {
        anchors.fill: root
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
    }

    onClicked: {
        GlobalStates.overviewOpen = false
        LauncherSearch.executeResult(root.entry)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete && event.modifiers === Qt.ShiftModifier) {
            LauncherSearch.resultActions(root.entry)
                .find(action => action.name === Translation.tr("Delete"))?.execute()
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked()
            event.accepted = true
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.horizontalMargin + root.clipboardHorizontalPadding
        anchors.rightMargin: root.horizontalMargin + root.clipboardHorizontalPadding
        spacing: 10

        MaterialSymbol {
            text: root.copied ? "check" : root.clipboardPresentation.icon
            iconSize: 30
            color: Qt.rgba(1, 1, 1, 0.92)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.clipboardPresentation.title
                textFormat: Text.PlainText
                renderType: Text.QtRendering
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Qt.rgba(1, 1, 1, 0.92)
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.clipboardPresentation.subtitle
                renderType: Text.QtRendering
                color: Qt.rgba(1, 1, 1, 0.58)
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideMiddle
            }
        }

        MaterialSymbol {
            text: "content_copy"
            iconSize: 20
            color: Qt.rgba(1, 1, 1, root.current ? 0.82 : 0.46)
        }
    }
}
