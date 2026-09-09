import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property int popupRadius: Appearance.rounding.large
    property bool animate: true
    property bool stickyHover: false
    property bool acceptsKeyboardFocus: false
    property bool holdOpen: false

    property bool _popupHovered: false
    property bool _stickyActive: false
    property bool _targetHovered: hoverTarget ? hoverTarget.containsMouse : false
    readonly property bool _requestedOpen: holdOpen
        || (stickyHover ? _stickyActive : (hoverTarget && hoverTarget.containsMouse))
    property bool _surfaceActive: false

    active: _surfaceActive

    // I have NO FUCKING IDEA why we cant use a normal timer here
    // Because if we do, we FUCKING cannot reference the timer from anywhere
    property QtObject _timers: QtObject {
        property Timer grace: Timer {
            interval: 100
            onTriggered: {
                root._popupHovered = false;
                root._stickyActive = false;
            }
        }
        property Timer close: Timer {
            interval: Appearance.animation.elementMoveExit.duration
            onTriggered: {
                if (!root._requestedOpen)
                    root._surfaceActive = false;
            }
        }
    }

    Component.onCompleted: root._surfaceActive = root._requestedOpen

    on_RequestedOpenChanged: {
        if (_requestedOpen) {
            _timers.close.stop();
            _surfaceActive = true;
            Qt.callLater(() => root.item?.showPopup());
            return;
        }

        if (!_surfaceActive)
            return;
        root.item?.hidePopup();
        _timers.close.restart();
    }

    function _evaluateStickyState() {
        if (!stickyHover) return;

        if (_targetHovered || _popupHovered) {
            _stickyActive = true;
            _timers.grace.stop();
        } else if (_stickyActive && !_timers.grace.running) {
            _timers.grace.start();
        }
    }

    on_TargetHoveredChanged: _evaluateStickyState()

    onHoldOpenChanged: {
        if (holdOpen && stickyHover) {
            _stickyActive = true;
            _timers.grace.stop();
        } else if (!holdOpen) {
            _evaluateStickyState();
        }
    }

    onActiveChanged: {
        if (!active) {
            _popupHovered = false;
            _timers.grace.stop();
        }
    }

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        readonly property real screenWidth: popupWindow.screen?.width ?? 0
        readonly property real screenHeight: popupWindow.screen?.height ?? 0

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.targetWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.targetHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: root._requestedOpen ? popupBackground : null
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    if (!root.hoverTarget || !root.QsWindow)
                        return 0;
                    var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                    var centeredX = targetPos.x + (root.hoverTarget.width - popupWindow.implicitWidth) / 2;
                    var minX = 0;
                    var maxX = screenWidth - popupWindow.implicitWidth;
                    return Math.max(minX, Math.min(maxX, centeredX));
                }
                return Appearance.sizes.verticalBarWidth;
            }

            top: {
                if (!Config.options.bar.vertical) {
                    return Appearance.sizes.barHeight;
                }
                if (!root.hoverTarget || !root.QsWindow)
                    return 0;
                var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                var centeredY = targetPos.y + (root.hoverTarget.height - popupWindow.implicitHeight) / 2;
                var minY = 0;
                var maxY = screenHeight - popupWindow.implicitHeight;
                return Math.max(minY, Math.min(maxY, centeredY));
            }

            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.acceptsKeyboardFocus
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None

        property real animProgress: 0.0
        function showPopup() {
            closeAnim.stop();
            openAnim.restart();
        }
        function hidePopup() {
            openAnim.stop();
            closeAnim.restart();
        }
        readonly property Item heroItem: {
            if (!root.contentItem) return null;
            for (let i = 0; i < root.contentItem.children.length; i++) {
                let child = root.contentItem.children[i];
                if (child.visible && child.width > 0) return child;
            }
            return null;
        }
        readonly property real heroHeight: heroItem ? heroItem.implicitHeight : 0

        Component.onCompleted: showPopup()

        NumberAnimation {
            id: openAnim
            target: popupWindow
            property: "animProgress"
            to: 1
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }

        NumberAnimation {
            id: closeAnim
            target: popupWindow
            property: "animProgress"
            to: 0
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Appearance.animation.elementMoveExit.type
            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10

            readonly property real targetWidth: (root.contentItem?.implicitWidth ?? 0) + margin * 2
            readonly property real targetHeight: (root.contentItem?.implicitHeight ?? 0) + margin * 2

            property bool isVertical: Config.options.bar.vertical
            property bool isBottom: Config.options.bar.bottom
            property int elevation: Appearance.sizes.elevationMargin

            // Debounced height — no auto-binding to targetHeight.
            // Batches rapid layout changes before triggering smooth animation.
            property real _commitHeight: 0
            // Delayed enable to avoid opening animation transition glitch
            property bool _heightReady: false

            Timer {
                id: heightCommit
                interval: 32
                repeat: false
                onTriggered: popupBackground._commitHeight = popupBackground.targetHeight
            }

            onTargetHeightChanged: {
                if (popupWindow.animProgress >= 1.0 && popupBackground._heightReady)
                    heightCommit.restart()
                else
                    _commitHeight = targetHeight
            }

            Component.onCompleted: {
                _commitHeight = targetHeight
                Qt.callLater(function() { popupBackground._heightReady = true })
            }

            Behavior on _commitHeight {
                enabled: popupBackground._heightReady
                SmoothedAnimation {
                    duration: 200
                    easing: Easing.OutQuad
                }
            }

            anchors {
                top: (!isVertical && !isBottom) ? parent.top : undefined
                bottom: (!isVertical && isBottom) ? parent.bottom : undefined
                left: (isVertical && !isBottom) ? parent.left : undefined
                right: (isVertical && isBottom) ? parent.right : undefined

                topMargin: top ? elevation : undefined
                bottomMargin: bottom ? elevation : undefined
                leftMargin: left ? elevation : undefined
                rightMargin: right ? elevation : undefined

                verticalCenter: isVertical ? parent.verticalCenter : undefined
                horizontalCenter: !isVertical ? parent.horizontalCenter : undefined
            }

            width: targetWidth
            height: {
                if (!root.animate || !root.contentItem || !heroItem || targetHeight <= heroHeight + margin * 2) return _commitHeight;
                return (heroHeight + margin * 2) + (_commitHeight - (heroHeight + margin * 2)) * popupWindow.animProgress;
            }

            color: Appearance.colors.colGlassSurfaceContainer
            radius: root.popupRadius
            antialiasing: true

            transform: Translate {
                x: popupBackground.isVertical
                    ? (1 - popupWindow.animProgress) * (popupBackground.isBottom ? popupBackground.width : -popupBackground.width)
                    : 0
                y: popupBackground.isVertical
                    ? 0
                    : (1 - popupWindow.animProgress) * (popupBackground.isBottom ? popupBackground.height : -popupBackground.height)
            }

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: popupBackground.margin
                clip: true

                Component.onCompleted: {
                    if (root.contentItem) {
                        root.contentItem.parent = contentContainer;
                        root.contentItem.anchors.centerIn = undefined;
                        root.contentItem.anchors.top = contentContainer.top;
                        root.contentItem.anchors.left = contentContainer.left;
                        root.contentItem.anchors.right = contentContainer.right;

                        for (let i = 0; i < root.contentItem.children.length; i++) {
                            let child = root.contentItem.children[i];

                            child.opacity = Qt.binding(() => {
                                if (!root.animate) return 1.0;
                                let normalizedDelay = child.y / popupBackground.targetHeight;
                                let progress = (popupWindow.animProgress - normalizedDelay) / (1.0 - normalizedDelay);
                                return Math.max(0, Math.min(1.0, progress));
                            });

                            child.scale = Qt.binding(() => {
                                if (!root.animate) return 1.0;
                                let normalizedDelay = child.y / popupBackground.targetHeight;
                                let progress = (popupWindow.animProgress - normalizedDelay) / (1.0 - normalizedDelay);
                                return 0.85 + (0.15 * Math.max(0, Math.min(1.0, progress)));
                            });
                        }
                    }
                }
            }

            HoverHandler {
                id: popupHoverHandler
                onHoveredChanged: {
                    root._popupHovered = hovered;
                    root._evaluateStickyState();
                }
            }

            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
    }
}
