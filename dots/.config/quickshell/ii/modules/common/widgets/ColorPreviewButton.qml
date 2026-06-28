import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root
    readonly property string builtInThemeDirectory: Directories.defaultThemes
    readonly property string customThemeDirectory: Directories.customThemes

    property string colorScheme: "scheme-auto"
    property string colorSchemeDisplayName: ""

    property bool builtInTheme: false
    readonly property string builtInThemeFilePath: builtInThemeDirectory + "/" + colorScheme + ".json"

    property bool customTheme: false
    readonly property string customThemeFilePath: customThemeDirectory + "/" + colorScheme + ".json"

    property var previewData: null

    // these are not actually primary, secondary and tertiary, they are just the three colors we get from the script
    property color primaryColor: "transparent"
    property color secondaryColor: "transparent"
    property color tertiaryColor: "transparent"

    property bool loaded: false
    property bool shouldLoad: false

    readonly property bool toggled: Config.options.appearance.palette.type === root.colorScheme
    readonly property bool sharpMode: Config.options.appearance.sharpMode

    colBackground: toggled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
    colBackgroundHover: toggled ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
    colRipple: toggled ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active

    buttonRadius: Appearance.rounding.small

    Layout.fillWidth: true
    implicitHeight: 64

    onClicked: {
        if (customTheme) {
            Config.options.appearance.palette.type = root.colorScheme;
            Quickshell.execDetached(["bash", "-c", `cp ${root.customThemeFilePath} ${Directories.generatedMaterialThemePath}`]);
        } else if (builtInTheme) {
            Config.options.appearance.palette.type = root.colorScheme;
            Quickshell.execDetached(["bash", "-c", `cp ${root.builtInThemeFilePath} ${Directories.generatedMaterialThemePath}`]);
        } else {
            Config.options.appearance.palette.type = root.colorScheme;
            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
        }
    }

    function applyPreview(data) {
        root.primaryColor = data?.primary || "transparent"
        root.secondaryColor = data?.primary_container || "transparent"
        root.tertiaryColor = data?.secondary || "transparent"
        root.loaded = true
        myCanvas.requestPaint()
    }

    function applyThemePreview(fileContent) {
        try {
            const data = JSON.parse(fileContent || "{}")
            root.applyPreview({
                primary: data.primary,
                primary_container: data.primary_container,
                secondary: data.secondary
            })
        } catch (e) {
            console.log("[ColorPreviewButton] Theme parse error:", root.colorScheme)
        }
    }

    onPreviewDataChanged: {
        if (!root.loaded && previewData) root.applyPreview(previewData)
    }

    onShouldLoadChanged: {
        if (!shouldLoad || loaded) return
        if (root.customTheme || root.builtInTheme) {
            themeFileView.reload()
            return
        }
        if (root.previewData) root.applyPreview(root.previewData)
    }

    FileView {
        id: themeFileView
        path: root.shouldLoad && (root.customTheme || root.builtInTheme) ? (root.customTheme ? root.customThemeFilePath : root.builtInThemeFilePath) : ""
        watchChanges: false
        onLoaded: root.applyThemePreview(themeFileView.text())
    }

    StyledToolTip {
        text: root.colorSchemeDisplayName
    }

    Item {
        anchors.fill: parent

        StyledText {
            anchors.fill: parent
            visible: !root.loaded
            elide: Text.ElideRight
            text: root.colorSchemeDisplayName
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colOnPrimaryContainer
            font.pixelSize: Appearance.font.pixelSize.small
        }

        Canvas {
            id: myCanvas
            anchors.centerIn: parent
            anchors.margins: 8

            implicitWidth: root.implicitHeight - 16
            implicitHeight: root.implicitHeight - 16

            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                var centerX = width / 2;
                var centerY = height / 2;
                var radius = width / 2;

                ctx.reset();

                if (root.sharpMode) {
                    ctx.fillStyle = root.primaryColor;
                    ctx.fillRect(0, 0, width, centerY);

                    ctx.fillStyle = root.secondaryColor;
                    ctx.fillRect(centerX, centerY, centerX, centerY);

                    ctx.fillStyle = root.tertiaryColor;
                    ctx.fillRect(0, centerY, centerX, centerY);
                } else {
                    ctx.beginPath();
                    ctx.fillStyle = root.primaryColor;
                    ctx.moveTo(centerX, centerY);
                    ctx.arc(centerX, centerY, radius, Math.PI, 0, false);
                    ctx.fill();

                    ctx.beginPath();
                    ctx.fillStyle = root.secondaryColor;
                    ctx.moveTo(centerX, centerY);
                    ctx.arc(centerX, centerY, radius, 0, Math.PI / 2, false);
                    ctx.fill();

                    ctx.beginPath();
                    ctx.fillStyle = root.tertiaryColor;
                    ctx.moveTo(centerX, centerY);
                    ctx.arc(centerX, centerY, radius, Math.PI / 2, Math.PI, false);
                    ctx.fill();
                }
            }
        }
    }
}
