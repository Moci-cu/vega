import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

RowLayout {
    id: root

    property int baseButtonWidth: 50
    property int baseButtonHeight: 50
    property real playPauseButtonWidthScale: 1.5
    property var player: MprisController.activePlayer

    spacing: Math.max(12, baseButtonWidth * 0.28)
    implicitWidth: controlsLayout.implicitWidth
    implicitHeight: controlsLayout.implicitHeight

    RowLayout {
        id: controlsLayout
        Layout.alignment: Qt.AlignHCenter
        spacing: root.spacing

        WatchControlButton {
            symbol: "skip_previous"
            size: root.baseButtonHeight * 0.9
            backgroundColor: Appearance.m3colors.m3primaryFixedDim
            backgroundHoverColor: Appearance.m3colors.m3primaryFixed
            rippleColor: Appearance.colors.colPrimaryContainerActive
            iconColor: Appearance.m3colors.m3onPrimaryFixed
            onClicked: root.player?.previous()
        }

        WatchControlButton {
            symbol: root.player?.isPlaying ? "pause" : "play_arrow"
            size: root.baseButtonHeight * root.playPauseButtonWidthScale
            expressive: true
            showProgressRing: true
            progressAnimated: true
            progress: root.player?.length > 0 ? root.player.position / root.player.length : 0
            backgroundColor: Appearance.m3colors.m3primaryFixed
            backgroundHoverColor: Appearance.m3colors.m3primaryFixedDim
            rippleColor: Appearance.colors.colPrimaryContainerActive
            iconColor: Appearance.m3colors.m3onPrimaryFixed
            outlineColor: Appearance.m3colors.m3primaryFixedDim
            progressColor: Appearance.m3colors.m3onPrimaryFixedVariant
            onClicked: root.player?.togglePlaying()
        }

        WatchControlButton {
            symbol: "skip_next"
            size: root.baseButtonHeight * 0.9
            backgroundColor: Appearance.m3colors.m3primaryFixedDim
            backgroundHoverColor: Appearance.m3colors.m3primaryFixed
            rippleColor: Appearance.colors.colPrimaryContainerActive
            iconColor: Appearance.m3colors.m3onPrimaryFixed
            onClicked: root.player?.next()
        }
    }

    component WatchControlButton: RippleButton {
        id: buttonRoot

        required property string symbol
        property real size: 48
        property bool expressive: false
        property bool showProgressRing: false
        property bool progressAnimated: false
        property real progress: 0
        property real snakePhase: 0
        property color backgroundColor: Appearance.colors.colSecondaryContainer
        property color backgroundHoverColor: Appearance.colors.colSecondaryContainerHover
        property color rippleColor: Appearance.colors.colSecondaryContainerActive
        property color iconColor: Appearance.colors.colOnSecondaryContainer
        property color outlineColor: Appearance.colors.colPrimary
        property color progressColor: Appearance.colors.colPrimary

        Layout.preferredWidth: size
        Layout.preferredHeight: size
        implicitWidth: size
        implicitHeight: size
        scale: down ? 0.94 : hovered ? 1.04 : 1
        buttonRadius: Appearance.rounding.full
        buttonRadiusPressed: Appearance.rounding.normal
        rippleDuration: 560
        colBackground: "transparent"
        colBackgroundHover: "transparent"
        colRipple: rippleColor

        Behavior on scale {
            animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
        }

        NumberAnimation on snakePhase {
            from: 0
            to: Math.PI * 2
            duration: 2600
            loops: Animation.Infinite
            running: buttonRoot.progressAnimated && buttonRoot.progress > 0
            easing.type: Easing.Linear
        }

        contentItem: Item {
            id: buttonContent

            implicitWidth: buttonRoot.size
            implicitHeight: buttonRoot.size

            Canvas {
                id: expressiveButtonCanvas
                width: parent.width + Math.max(18, buttonRoot.size * 0.24)
                height: parent.height + Math.max(18, buttonRoot.size * 0.24)
                anchors.centerIn: parent
                visible: buttonRoot.expressive
                opacity: 1
                onPaint: {
                    var context = getContext("2d")
                    var progress = Math.max(0, Math.min(1, buttonRoot.progress))
                    var strokeWidth = Math.max(2.4, buttonRoot.size * 0.044)
                    var radius = buttonRoot.size / 2 - strokeWidth * 2.35 - 3
                    var amplitude = buttonRoot.size * 0.085
                    var waveCount = 10
                    var centerX = width / 2
                    var centerY = height / 2
                    var startAngle = -Math.PI / 2
                    var endAngle = startAngle + Math.PI * 2 * progress
                    var borderWidth = Math.max(1.7, strokeWidth * 0.58)
                    var progressWidth = Math.max(2.5, strokeWidth * 0.82)
                    var progressRadius = radius + Math.max(3.6, amplitude * 0.55)

                    // Draw scalloped shape using bezier curves
                    function drawScallopedShape(r, bumpHeight, numBumps) {
                        var angleStep = Math.PI * 2 / numBumps
                        context.beginPath()
                        for (var i = 0; i < numBumps; i++) {
                            var a0 = i * angleStep
                            var a1 = a0 + angleStep * 0.5
                            var a2 = a0 + angleStep

                            // Start point on circle
                            var sx = centerX + r * Math.cos(a0)
                            var sy = centerY + r * Math.sin(a0)

                            // Peak point (outward bump)
                            var px = centerX + (r + bumpHeight) * Math.cos(a1)
                            var py = centerY + (r + bumpHeight) * Math.sin(a1)

                            // End point on circle
                            var ex = centerX + r * Math.cos(a2)
                            var ey = centerY + r * Math.sin(a2)

                            if (i === 0)
                                context.moveTo(sx, sy)

                            // Quadratic bezier through the bump peak
                            context.quadraticCurveTo(px, py, ex, ey)
                        }
                        context.closePath()
                    }

                    function strokeScallopedShape(alpha, lineWidth, color, shapeRadius) {
                        context.strokeStyle = color
                        context.globalAlpha = alpha
                        context.lineWidth = lineWidth
                        context.lineCap = "round"
                        context.lineJoin = "round"
                        drawScallopedShape(shapeRadius, amplitude, waveCount)
                        context.stroke()
                    }

                    function clipProgressSector(fromAngle, toAngle) {
                        var clipRadius = Math.min(width, height)
                        context.beginPath()
                        context.moveTo(centerX, centerY)
                        context.arc(centerX, centerY, clipRadius, fromAngle, toAngle)
                        context.closePath()
                        context.clip()
                    }

                    function strokeProgressPulse(progressSpan) {
                        var pulse = (Math.sin(buttonRoot.snakePhase) + 1) * 0.5
                        context.save()
                        clipProgressSector(startAngle, startAngle + progressSpan)
                        context.strokeStyle = buttonRoot.progressColor
                        context.globalAlpha = 0.16 + pulse * 0.14
                        context.lineWidth = progressWidth + pulse * 0.9
                        drawScallopedShape(progressRadius, amplitude, waveCount)
                        context.stroke()
                        context.restore()
                    }

                    context.clearRect(0, 0, width, height)
                    context.lineCap = "round"
                    context.lineJoin = "round"

                    // Fill scalloped shape
                    context.globalAlpha = 1
                    context.fillStyle = buttonRoot.hovered ? buttonRoot.backgroundHoverColor : buttonRoot.backgroundColor
                    drawScallopedShape(radius, amplitude, waveCount)
                    context.fill()

                    // Progress contour, following the scalloped face like Wear OS.
                    if (buttonRoot.showProgressRing) {
                        strokeScallopedShape(0.48, borderWidth, buttonRoot.progressColor, radius)
                        strokeScallopedShape(0.82, progressWidth, buttonRoot.outlineColor, progressRadius)
                        if (progress > 0) {
                            context.save()
                            clipProgressSector(startAngle, endAngle)
                            strokeScallopedShape(1, progressWidth, buttonRoot.progressColor, progressRadius)
                            context.restore()

                            if (buttonRoot.progressAnimated) {
                                strokeProgressPulse(Math.PI * 2 * progress)
                            }
                        }
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: buttonRoot
                    function onProgressChanged() {
                        expressiveButtonCanvas.requestPaint()
                    }
                    function onSnakePhaseChanged() {
                        expressiveButtonCanvas.requestPaint()
                    }
                    function onBackgroundColorChanged() {
                        expressiveButtonCanvas.requestPaint()
                    }
                    function onBackgroundHoverColorChanged() {
                        expressiveButtonCanvas.requestPaint()
                    }
                    function onHoveredChanged() {
                        expressiveButtonCanvas.requestPaint()
                    }
                    function onOutlineColorChanged() {
                        expressiveButtonCanvas.requestPaint()
                    }
                    function onProgressColorChanged() {
                        expressiveButtonCanvas.requestPaint()
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: !buttonRoot.expressive
                color: buttonRoot.hovered ? buttonRoot.backgroundHoverColor : buttonRoot.backgroundColor

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: buttonRoot.symbol
                iconSize: buttonRoot.expressive ? 28 : 22
                fill: 1
                color: buttonRoot.iconColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
