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
            progress: root.player?.length > 0 ? root.player.position / root.player.length : 0
            backgroundColor: Appearance.m3colors.m3primaryFixed
            backgroundHoverColor: Appearance.m3colors.m3primaryFixedDim
            rippleColor: Appearance.colors.colPrimaryContainerActive
            iconColor: Appearance.m3colors.m3onPrimaryFixed
            outlineColor: Appearance.m3colors.m3onPrimaryFixedVariant
            progressColor: Appearance.m3colors.m3onPrimaryFixed
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
        property real progress: 0
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

        contentItem: Item {
            id: buttonContent

            implicitWidth: buttonRoot.size
            implicitHeight: buttonRoot.size

            Canvas {
                id: expressiveButtonCanvas
                anchors.fill: parent
                visible: buttonRoot.expressive
                opacity: 1
                onPaint: {
                    var context = getContext("2d")
                    var progress = Math.max(0, Math.min(1, buttonRoot.progress))
                    var strokeWidth = Math.max(2.5, buttonRoot.size * 0.048)
                    var radius = Math.min(width, height) / 2 - strokeWidth * 1.25 - 1
                    var amplitude = buttonRoot.size * 0.09
                    var waveCount = 10
                    var centerX = width / 2
                    var centerY = height / 2
                    var startAngle = -Math.PI / 2
                    var endAngle = startAngle + Math.PI * 2 * progress

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

                    context.clearRect(0, 0, width, height)
                    context.lineCap = "round"
                    context.lineJoin = "round"

                    // Fill scalloped shape
                    context.globalAlpha = 1
                    context.fillStyle = buttonRoot.hovered ? buttonRoot.backgroundHoverColor : buttonRoot.backgroundColor
                    drawScallopedShape(radius, amplitude, waveCount)
                    context.fill()

                    // Outline
                    context.strokeStyle = buttonRoot.outlineColor
                    context.globalAlpha = 0.72
                    context.lineWidth = strokeWidth * 0.82
                    drawScallopedShape(radius, amplitude, waveCount)
                    context.stroke()

                    // Progress ring — simple circle arc
                    if (buttonRoot.showProgressRing) {
                        context.globalAlpha = 0.96
                        context.strokeStyle = buttonRoot.progressColor
                        context.lineWidth = strokeWidth
                        context.beginPath()
                        context.arc(centerX, centerY, radius + amplitude + strokeWidth * 0.5, startAngle, endAngle)
                        context.stroke()
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: buttonRoot
                    function onProgressChanged() {
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
