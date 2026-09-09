// Adapted from Unit-4, Copyright (c) 2026 samyns (MIT).
// See assets/wallpaper-picker/LICENSE.
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import Qt.labs.folderlistmodel
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

pragma ComponentBehavior: Bound

Scope {
    id: root

    // ── État partagé ──
    property bool   revealing: false
    property bool   frozen:    false
    property bool   hiding:    false
    property bool   done:      false

    property var wallpapers: {
        const files = [];
        for (let i = 0; i < wallpaperFiles.count; ++i)
            files.push({ path: wallpaperFiles.get(i, "filePath"),
                url: wallpaperFiles.get(i, "fileUrl"), name: wallpaperFiles.get(i, "fileName") });
        return files;
    }
    property int currentIndex: 0
    readonly property string activeMonitor: Hyprland.focusedMonitor?.name
        ?? Quickshell.screens[0]?.name ?? ""

    FolderListModel {
        id: wallpaperFiles
        folder: Wallpapers.directory
        nameFilters: Wallpapers.extensions.map(extension => "*." + extension)
        caseSensitive: false
        showDirs: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
    }
    onWallpapersChanged: {
        const selected = wallpapers.findIndex(file => file.path === Config.options.background.wallpaperPath);
        currentIndex = selected >= 0 ? selected : 0;
    }
    Component.onCompleted: root.revealing = true

    function applyWallpaper(idx) {
        const file = root.wallpapers[idx];
        if (!file || root.hiding) return;
        Wallpapers.apply(file.path);
        root.doClose();
    }

    // ── Gestion du curseur Hyprland ──
    // Le curseur natif Hyprland reste visible en permanence : on ne touche
    // ni à cursor:invisible avant ni à la fermeture.

    // Horloge
    property string clockFull: "--:--:--"
    Timer {
        interval:1000;running:true;repeat:true
        onTriggered:{
            var d=new Date(),p=function(x){return String(x).padStart(2,"0")}
            root.clockFull=p(d.getHours())+":"+p(d.getMinutes())+":"+p(d.getSeconds())
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top:true;anchors.left:true;anchors.right:true;anchors.bottom:true
            exclusionMode: ExclusionMode.Ignore
            color: "#0b0906"
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            implicitWidth: modelData.width; implicitHeight: modelData.height
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (root.frozen && !root.hiding && !root.done
                                          && modelData.name === root.activeMonitor)
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            property bool isPrimary: modelData.name === root.activeMonitor
            property bool isActive:  modelData.name === root.activeMonitor

            // ── Vidéo reveal ──
            MediaPlayer {
                id: reveal
                source: "file://" + FileUtils.trimFileProtocol(Qt.resolvedUrl("../../../assets/wallpaper-picker/wave_reveal.mp4"))
                videoOutput: voReveal
                audioOutput: null
                loops: 1; autoPlay: false
                onErrorOccurred: (error, message) => console.warn("[WallpaperPicker] " + message)
                onPositionChanged: function() {
                    if (root.hiding || root.done) return
                    var pos = reveal.position
                    var dur = reveal.duration
                    if (dur > 0 && pos >= dur - 34) {
                        reveal.pause()
                        root.revealing = false
                    }
                }
            }
            VideoOutput {
                id: voReveal
                anchors.fill: parent
                visible: !root.done
            }

            // ── Vidéo hide ──
            MediaPlayer {
                id: hide
                source: "file://" + FileUtils.trimFileProtocol(Qt.resolvedUrl("../../../assets/wallpaper-picker/wave_hide.mp4"))
                videoOutput: voHide
                audioOutput: null
                loops: 1; autoPlay: false
            }
            VideoOutput {
                id: voHide
                anchors.fill: parent; z:1
                visible: root.hiding || root.done
                opacity: 1.0
            }

            Timer {
                id: hideFadeTimer; interval:550; repeat:false
                onTriggered: hideFadeAnim.start()
            }
            NumberAnimation {
                id: hideFadeAnim
                target: voHide; property: "opacity"
                from:1.0; to:0.0; duration:250
                easing.type: Easing.InQuad
                onFinished: { root.done=true; exitTimer.restart() }
            }
            Timer { id:exitTimer; interval:50; repeat:false
                onTriggered: GlobalStates.wallpaperSelectorOpen = false
            }
            Rectangle { anchors.fill:parent; color:"black"; z:10; visible:root.done }

            // ── UI — seulement sur l'écran actif ──
            Item {
                anchors.fill: parent
                visible: !root.done && isActive
                z: 2

                property real uiOp: (root.frozen || root.revealing) ? 1 : 0
                Behavior on uiOp { NumberAnimation { duration:400 } }

                // Scroll souris sur toute la surface
                MouseArea {
                    anchors.fill: parent
                    onWheel: function(e) {
                        root.navigate(e.angleDelta.y < 0 ? 1 : -1)
                    }
                }

                // Coins déco
                Item {
                    anchors{top:parent.top;left:parent.left;topMargin:28;leftMargin:30}
                    z:5; opacity:parent.uiOp
                    Column { spacing:2
                        Row { spacing:5
                            Rectangle { width:5;height:5;radius:3;color:"#6e2a2a"
                                anchors.verticalCenter:parent.verticalCenter
                                SequentialAnimation on opacity { running:root.frozen; loops:Animation.Infinite
                                    NumberAnimation{to:0.3;duration:900} NumberAnimation{to:1;duration:900} }
                            }
                            Text{text:"WALLPAPER SELECT";font.family: "Ndot 57";font.pixelSize:9;font.letterSpacing:2;color:"#463f2e"}
                        }
                        Text{text:"NODE · "+root.activeMonitor;font.family: "Ndot 57";font.pixelSize:9;font.letterSpacing:2;color:"#463f2e"}
                    }
                }
                Item {
                    anchors{top:parent.top;right:parent.right;topMargin:28;rightMargin:30}
                    z:5; opacity:parent.uiOp
                    Text{text:root.clockFull;font.family: "Ndot 57";font.pixelSize:9;font.letterSpacing:2;color:"#463f2e"}
                }
                Item {
                    anchors{bottom:parent.bottom;left:parent.left;bottomMargin:28;leftMargin:30}
                    z:5; opacity:parent.uiOp
                    Text{text:"H/L  NAVIGATE  ·  ENTER  APPLY ALL  ·  ESC  QUIT";font.family: "Ndot 57";font.pixelSize:9;font.letterSpacing:2;color:"#463f2e"}
                }

                // ── Boutons apply — toujours visibles ──
                Item {
                    id: applyPanel
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 60
                    width: 420
                    height: applyCol.implicitHeight + 48
                    z: 7
                    opacity: root.frozen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration:300 } }

                    Rectangle {
                        anchors.fill: parent
                        color: "#d6cfb5"
                        border.color: "#463f2e"; border.width: 1

                        Repeater { model:22; Rectangle{ required property int index; x:index*20;y:0;width:1;height:parent.height;color:Qt.rgba(70/255,63/255,46/255,0.06)} }

                        Column {
                            id: applyCol
                            width: 348
                            anchors{top:parent.top;topMargin:20;horizontalCenter:parent.horizontalCenter}
                            spacing: 10

                            Text {
                                text: "APPLY WALLPAPER"
                                font.family: "Ndot 57";font.pixelSize:10;font.letterSpacing:3
                                color:"#463f2e";anchors.horizontalCenter:parent.horizontalCenter
                            }
                            Rectangle { width:parent.width;height:1;color:Qt.rgba(70/255,63/255,46/255,0.22) }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12

                                // Bouton écran actif
                                Item { width:162; height:42
                                    Rectangle { anchors.fill:parent;color:"transparent";border.color:"#463f2e";border.width:1 }
                                    Rectangle { id:fill1;anchors.left:parent.left;anchors.top:parent.top;anchors.bottom:parent.bottom;color:"#463f2e";width:0
                                        Behavior on width{NumberAnimation{duration:220}} }
                                    Text { anchors.centerIn:parent
                                        text:"CANCEL"
                                        font.family: "Ndot 57";font.pixelSize:10;font.letterSpacing:2
                                        color:ma1.containsMouse?"#d6cfb5":"#463f2e"
                                        Behavior on color{ColorAnimation{duration:200}} }
                                    MouseArea { id:ma1;anchors.fill:parent;hoverEnabled:true
                                        onEntered:fill1.width=parent.width;onExited:fill1.width=0
                                        onClicked:{ root.doClose() } }
                                }

                                // Bouton les deux écrans
                                Item { width:162; height:42
                                    Rectangle { anchors.fill:parent;color:"transparent";border.color:"#463f2e";border.width:1 }
                                    Rectangle { id:fill2;anchors.left:parent.left;anchors.top:parent.top;anchors.bottom:parent.bottom;color:"#463f2e";width:0
                                        Behavior on width{NumberAnimation{duration:220}} }
                                    Text { anchors.centerIn:parent
                                        text:"ALL SCREENS"
                                        font.family: "Ndot 57";font.pixelSize:10;font.letterSpacing:2
                                        color:ma2.containsMouse?"#d6cfb5":"#463f2e"
                                        Behavior on color{ColorAnimation{duration:200}} }
                                    MouseArea { id:ma2;anchors.fill:parent;hoverEnabled:true
                                        onEntered:fill2.width=parent.width;onExited:fill2.width=0
                                        onClicked:{ root.applyWallpaper(root.currentIndex) } }
                                }
                            }
                        }
                    }
                }

                // ── Carrousel ──
                // ── Carrousel ──
                Item {
                    id: carousel
                    anchors.top: parent.top
                    anchors.topMargin: 80
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: parent.height - 220
                    z: 6
                    opacity: root.frozen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration:300 } }

                    focus: root.frozen && isActive
                    Keys.onEscapePressed: root.doClose()
                    Keys.onLeftPressed:   root.navigate(-1)
                    Keys.onRightPressed:  root.navigate(1)
                    Keys.onUpPressed:     root.navigate(-1)
                    Keys.onDownPressed:   root.navigate(1)
                    Keys.onReturnPressed: { root.applyWallpaper(root.currentIndex) }
                    Keys.onPressed: function(ev) {
                        if (ev.key === Qt.Key_H) root.navigate(-1)
                        else if (ev.key === Qt.Key_L) root.navigate(1)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.wallpapers.length === 0
                        text: "No images in " + Wallpapers.effectiveDirectory
                        color: "#463f2e"
                        font.pixelSize: 18
                    }

                    readonly property int n: root.wallpapers.length

                    // Dimensions de base (taille de la vignette centrale à pleine échelle)
                    readonly property int baseW: Math.min(800, width * 0.55, Math.max(200, height - 40) * 1.6)
                    readonly property int baseH: baseW / 1.6
                    // Ligne de base commune : toutes les vignettes ont leur bas aligné ici
                    readonly property int baselineY: height / 2 + baseH / 2

                    // Échelles par distance (slot) au centre
                    readonly property real scaleCenter: 1.0
                    readonly property real scaleNear:   0.54   // ~280/520
                    readonly property real scaleFar:    0.35   // ~180/520

                    // Espacements X (demi-axes entre centres de vignettes) par slot
                    readonly property int offsetNear: baseW * 0.35
                    readonly property int offsetFar: baseW * 0.72

                    // Une vignette par wallpaper. Chaque vignette choisit sa place
                    // en fonction de l'offset signé vers currentIndex (chemin le plus
                    // court sur la boucle). Position, scale et opacity sont animées
                    // -> le zoom est smooth et part du bas (transformOrigin: Bottom).
                    Repeater {
                        model: root.wallpapers

                        Item {
                            id: thumb
                            required property int index
                            property int wIdx: index
                            readonly property bool isVideo: Wallpapers.isVideoFile(root.wallpapers[wIdx].name)
                            // Offset signé (-n/2 .. n/2) = chemin le plus court vers currentIndex
                            property int rawDelta: carousel.n > 0 ? (wIdx - root.currentIndex) : 0
                            property int delta: {
                                if (carousel.n === 0) return 0
                                var d = rawDelta
                                var half = carousel.n / 2
                                if (d >  half) d -= carousel.n
                                if (d < -half) d += carousel.n
                                return d
                            }
                            property int absDelta: Math.abs(delta)

                            // Position X et échelle dérivées du slot
                            property real targetScale:
                                  absDelta === 0 ? carousel.scaleCenter
                                : absDelta === 1 ? carousel.scaleNear
                                :                  carousel.scaleFar
                            property real targetOpacity:
                                  absDelta === 0 ? 1.0
                                : absDelta === 1 ? 0.65
                                : absDelta === 2 ? 0.3
                                :                  0.0
                            property int targetOffsetX:
                                  absDelta === 0 ? 0
                                : absDelta === 1 ? (delta > 0 ?  carousel.offsetNear : -carousel.offsetNear)
                                :                  (delta > 0 ?  carousel.offsetFar  : -carousel.offsetFar)

                            width: carousel.baseW
                            height: carousel.baseH
                            x: carousel.width/2 + targetOffsetX - carousel.baseW/2
                            y: carousel.baselineY - carousel.baseH
                            scale: targetScale
                            opacity: targetOpacity
                            z: absDelta === 0 ? 10 : (3 - absDelta)
                            visible: absDelta <= 2
                            transformOrigin: Item.Bottom

                            // Animations fluides — le scale part du bas grâce au transformOrigin
                            Behavior on x       { NumberAnimation { duration:320; easing.type:Easing.OutCubic } }
                            Behavior on scale   { NumberAnimation { duration:320; easing.type:Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration:320; easing.type:Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                color: "#0f0d0a"
                                border.color: thumb.absDelta === 0 ? "#e0c888" : "#463f2e"
                                border.width: thumb.absDelta === 0 ? 2 : 1
                                Behavior on border.color { ColorAnimation { duration:260 } }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: thumb.absDelta <= 2 && !thumb.isVideo
                                        ? root.wallpapers[thumb.wIdx].url
                                        : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    sourceSize.width: 640
                                    sourceSize.height: 400
                                }

                                Loader {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    active: thumb.isVideo && thumb.absDelta <= 2 && !root.hiding
                                    sourceComponent: VideoOutput {
                                        id: videoPreview
                                        fillMode: VideoOutput.PreserveAspectCrop
                                        MediaPlayer {
                                            source: root.wallpapers[thumb.wIdx].url
                                            videoOutput: videoPreview
                                            audioOutput: null
                                            autoPlay: true
                                            loops: MediaPlayer.Infinite
                                            onErrorOccurred: (error, message) => console.warn("[WallpaperPicker] " + message)
                                        }
                                    }
                                }

                                // Bandeau avec le nom, visible seulement sur la vignette centrale
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 24
                                    color: Qt.rgba(0,0,0,0.6)
                                    opacity: thumb.absDelta === 0 ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration:200 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.wallpapers[thumb.wIdx].name
                                        font.family: "Ndot 57"
                                        font.pixelSize: 8
                                        color: "#e0c888"
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                // Clic sur une voisine -> on navigue vers elle
                                onClicked: if (thumb.delta !== 0) root.navigate(thumb.delta)
                                onWheel: function(e) { root.navigate(e.angleDelta.y < 0 ? 1 : -1) }
                            }
                        }
                    }
                }
            }

            // ── Connexions état ──
            Connections {
                target: root
                function onRevealingChanged() {
                    if (root.revealing) {
                        root.frozen = true
                        reveal.position = 0
                        reveal.play()
                        panelOpenTimer.restart()
                    }
                }
                function onHidingChanged() {
                    if (root.hiding) {
                        reveal.stop()
                        hide.position = 0
                        hide.play()
                        if (isPrimary) hideFadeTimer.restart()
                    }
                }
            }
            Timer { id:panelOpenTimer; interval:100; repeat:false; onTriggered: carousel.forceActiveFocus() }
        }
    }

    // ── Navigation ──
    function navigate(dir) {
        var n = root.wallpapers.length
        if (n === 0 || root.hiding) return
        root.currentIndex = ((root.currentIndex + dir) % n + n) % n
    }

    function doClose() {
        if (root.hiding) return;
        root.hiding = true
    }
}
