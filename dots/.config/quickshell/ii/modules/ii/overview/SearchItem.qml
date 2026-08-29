// pragma NativeMethodBehavior: AcceptThisObject
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

RippleButton {
    id: root
    property var entry
    property string query
    property bool current: false
    readonly property string entryKey: entry?.key ?? ""
    readonly property bool isAppResult: entry?.nativeApp ?? entryKey.startsWith("app:")
    readonly property bool isClipboardResult: entryKey.startsWith("clipboard:")
    readonly property bool isFileResult: entryKey.startsWith("file:")
    property string cliphistRawString: isClipboardResult ? entry?.rawValue ?? "" : ""
    readonly property var clipboardPresentation: isClipboardResult
        ? Cliphist.presentation(cliphistRawString) : null
    property bool entryShown: entry?.shown ?? true
    property string itemType: entry?.nativeApp ? Translation.tr("App") : entry?.type ?? Translation.tr("App")
    property string itemName: isClipboardResult
        ? clipboardPresentation?.title ?? "" : entry?.name ?? ""
    property var iconType: isClipboardResult ? LauncherSearchResult.IconType.Material
        : entry?.nativeApp ? LauncherSearchResult.IconType.System : entry?.iconType
    property string iconName: entry?.iconName ?? ""
    property var fontType: switch(entry?.fontType) {
        case LauncherSearchResult.FontType.Monospace:
            return "monospace"
        case LauncherSearchResult.FontType.Normal:
            return "main"
        default:
            return "main"
    }
    property string itemClickActionName: entry?.nativeApp ? Translation.tr("Open") : entry?.verb ?? "Open"
    property string bigText: entry?.iconType === LauncherSearchResult.IconType.Text ? entry?.iconName ?? "" : ""
    property string materialSymbol: isClipboardResult ? clipboardPresentation?.icon ?? "description"
        : entry?.iconType === LauncherSearchResult.IconType.Material ? entry?.iconName ?? "" : ""
    property string filePath: isFileResult && Images.isValidImageByName(entry?.name) ? entry?.name : ""
    property bool blurImage: entry?.blurImage ?? false
    
    visible: root.entryShown
    property int horizontalMargin: 10
    property int buttonHorizontalPadding: 10
    property int buttonVerticalPadding: 6
    property real containerRadius: Appearance.rounding.normal + horizontalMargin
    property bool keyboardDown: false
    readonly property bool selected: root.current

    implicitHeight: root.isClipboardResult ? 58 : rowLayout.implicitHeight + root.buttonVerticalPadding * 2
    implicitWidth: rowLayout.implicitWidth + root.buttonHorizontalPadding * 2
    buttonRadius: Math.max(0, root.containerRadius - root.horizontalMargin)
    colBackground: root.isClipboardResult
        ? (root.selected ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        : (root.down || root.keyboardDown) ? Appearance.colors.colPrimaryContainerActive
        : (selected ? Appearance.colors.colPrimaryContainer
        : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 1))
    colBackgroundHover: root.isClipboardResult ? Qt.rgba(1, 1, 1, 0.1)
        : root.selected ? Appearance.colors.colPrimaryContainer
        : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 1)
    colRipple: root.isClipboardResult ? Qt.rgba(1, 1, 1, 0.16) : Appearance.colors.colPrimaryContainerActive
    property color colForeground: root.isClipboardResult ? Qt.rgba(1, 1, 1, 0.92)
        : selected ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onSurface

    readonly property string highlightPrefix: `<u><font color="${Appearance.colors.colPrimary}">`
    readonly property string highlightSuffix: `</font></u>`
    // Note that this highlighting is independent from the search
    // It's close, but does not accurately represent how the fuzzy algorithm works
    function highlightContent(content, query) {
        if (!query || query.length === 0 || content == query || fontType === "monospace")
            return StringUtils.escapeHtml(content);

        let contentLower = content.toLowerCase();
        let queryLower = query.toLowerCase();

        let result = "";
        let lastIndex = 0;
        let qIndex = 0;

        for (let i = 0; i < content.length && qIndex < query.length; i++) {
            if (contentLower[i] === queryLower[qIndex]) {
                // Add non-highlighted part (escaped)
                if (i > lastIndex)
                    result += StringUtils.escapeHtml(content.slice(lastIndex, i));
                // Add highlighted character (escaped)
                result += root.highlightPrefix + StringUtils.escapeHtml(content[i]) + root.highlightSuffix;
                lastIndex = i + 1;
                qIndex++;
            }
        }
        // Add the rest of the string (escaped)
        if (lastIndex < content.length)
            result += StringUtils.escapeHtml(content.slice(lastIndex));

        return result;
    }
    property string displayContent: root.isAppResult ? root.itemName : highlightContent(root.itemName, root.query)

    property list<string> urls: {
        if (root.isAppResult || !root.itemName) return [];
        // Regular expression to match URLs
        const urlRegex = /https?:\/\/[^\s<>"{}|\\^`[\]]+/gi;
        const matches = root.itemName?.match(urlRegex)
            ?.filter(url => !url.includes("…")) // Elided = invalid
        return matches ? matches : [];
    }
    
    PointingHandInteraction {}

    background {
        anchors.fill: root
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
    }

    onClicked: {
        GlobalStates.overviewOpen = false
        LauncherSearch.executeResult(root.entry)
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Delete && event.modifiers === Qt.ShiftModifier) {
            const deleteAction = LauncherSearch.resultActions(root.entry).find(action => action.name == Translation.tr("Delete"));

            if (deleteAction) {
                deleteAction.execute()
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = true
            root.clicked()
            event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = false
            event.accepted = true;
        }
    }

    RowLayout {
        id: rowLayout
        spacing: iconLoader.sourceComponent === null ? 0 : 10
        anchors.fill: parent
        anchors.leftMargin: root.horizontalMargin + root.buttonHorizontalPadding
        anchors.rightMargin: root.horizontalMargin + root.buttonHorizontalPadding

        // Icon
        Loader {
            id: iconLoader
            active: true
            sourceComponent: switch(root.iconType) {
                case LauncherSearchResult.IconType.Material:
                    return materialSymbolComponent
                case LauncherSearchResult.IconType.Text:
                    return bigTextComponent
                case LauncherSearchResult.IconType.System:
                    return iconImageComponent
                case LauncherSearchResult.IconType.None:
                    return null
                default:
                    return null
            }
        }

        Component {
            id: iconImageComponent
            IconImage {
                source: AppSearch.iconPath(root.iconName, "image-missing")
                asynchronous: true
                width: 35
                height: 35
            }
        }

        Component {
            id: materialSymbolComponent
            MaterialSymbol {
                text: root.materialSymbol
                iconSize: 30
                color: root.colForeground
            }
        }

        Component {
            id: bigTextComponent
            StyledText {
                text: root.bigText
                font.pixelSize: Appearance.font.pixelSize.larger
                color: root.colForeground
            }
        }

        // Main text
        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                visible: !root.isClipboardResult && root.itemType && root.itemType != Translation.tr("App")
                text: root.itemType
            }
            RowLayout {
                Loader { // Checkmark for copied clipboard entry
                    visible: !root.isClipboardResult && itemName == Quickshell.clipboardText && root.cliphistRawString
                    active: visible
                    sourceComponent: Rectangle {
                        implicitWidth: activeText.implicitHeight
                        implicitHeight: activeText.implicitHeight
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            id: activeText
                            anchors.centerIn: parent
                            text: "check"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }
                Repeater { // Favicons for links
                    model: root.isClipboardResult || root.query == root.itemName ? [] : root.urls
                    Favicon {
                        required property var modelData
                        size: parent.height
                        url: modelData
                    }
                }
                StyledText { // Item name/content
                    Layout.fillWidth: true
                    id: nameText
                    textFormat: root.isAppResult || root.isClipboardResult ? Text.PlainText : Text.StyledText
                    renderType: root.isClipboardResult ? Text.QtRendering : Text.NativeRendering
                    font.pixelSize: root.isClipboardResult ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
                    font.family: Appearance.font.family[root.fontType]
                    font.weight: root.isClipboardResult ? Font.DemiBold : Font.Normal
                    color: root.colForeground
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: root.selected || root.isAppResult ? root.itemName : root.displayContent
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.isClipboardResult
                renderType: Text.QtRendering
                text: root.clipboardPresentation?.subtitle ?? ""
                color: Qt.rgba(1, 1, 1, 0.58)
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideMiddle
            }

            Loader { // File search image preview
                active: root.filePath != ""
                sourceComponent: FileSearchImage {
                    Layout.fillWidth: true
                    imagePath: root.filePath
                    maxWidth: contentColumn.width
                    maxHeight: 140
                    blur: Config.options.search.blurFileSearchResultPreviews
                }
            }
        }

        // Action text
        StyledText {
            Layout.fillWidth: false
            visible: root.selected && !root.isClipboardResult
            id: clickAction
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnPrimaryContainer
            horizontalAlignment: Text.AlignRight
            text: root.itemClickActionName
        }

        RowLayout {
            Layout.alignment: root.isClipboardResult ? Qt.AlignVCenter : Qt.AlignTop
            Layout.topMargin: root.isClipboardResult ? 0 : root.buttonVerticalPadding
            Layout.bottomMargin: root.isClipboardResult ? 0 : -root.buttonVerticalPadding
            spacing: 4
            Repeater {
                model: root.isClipboardResult ? LauncherSearch.resultActions(root.entry, 1)
                    : root.selected ? LauncherSearch.resultActions(root.entry, 4) : []
                delegate: RippleButton {
                    id: actionButton
                    required property var modelData
                    property var iconType: modelData.iconType
                    property string iconName: modelData.iconName ?? ""
                    implicitHeight: 34
                    implicitWidth: 34
                    buttonRadius: 17

                    colBackground: root.isClipboardResult ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive

                    contentItem: Item {
                        id: actionContentItem
                        anchors.centerIn: parent
                        Loader {
                            anchors.centerIn: parent
                            active: actionButton.iconType === LauncherSearchResult.IconType.Material || actionButton.iconName === ""
                            sourceComponent: MaterialSymbol {
                                text: actionButton.iconName || "video_settings"
                                font.pixelSize: Appearance.font.pixelSize.hugeass
                                color: root.colForeground
                            }
                        }
                        Loader {
                            anchors.centerIn: parent
                            active: actionButton.iconType === LauncherSearchResult.IconType.System && actionButton.iconName !== ""
                            sourceComponent: IconImage {
                                source: AppSearch.iconPath(actionButton.iconName)
                                asynchronous: true
                                implicitSize: 20
                            }
                        }
                    }

                    onClicked: modelData.execute()

                    StyledToolTip {
                        text: modelData.name
                    }
                }
            }
        }

    }
}
