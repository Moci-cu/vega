import qs.modules.common
import qs.services
import QtQuick

// Shows synced lyrics from Lrclib
// default values are for media mode visuals, but these can be overridden by the parent

Item {
    id: root
    visible: LyricsService.syncedLines.length > 0
    clip: true

    readonly property bool hasSyncedLines: LyricsService.syncedLines.length > 0
    readonly property real baseY: (height - rowHeight) / 2
    property int visibleLineCount: halfVisibleLines * 2 + 1
    readonly property int targetCurrentIndex: hasSyncedLines ? LyricsService.currentIndex : -1

    property int rowHeight: Math.max(30, Math.min(Math.floor(height / 5), Appearance.font.pixelSize.hugeass * 3))
    property real downScale: 0.85
    property int halfVisibleLines: 3
    property bool useGradientMask: true
    property real gradientDensity: 1.0

    property real defaultLyricsSize: Appearance.font.pixelSize.normal * 1.5
    property string textAlign: "center"
    property bool changeTextWeight: false

    property int lastIndex: -1
    property bool isMovingForward: true
    property real scrollOffset: 0
    property int scrollDuration: 300

    readonly property real animProgress: Math.abs(scrollOffset) / rowHeight
    readonly property real playbackPosition: {
        const position = Number(LyricsService.activePlayer?.position ?? 0)
        return isFinite(position) ? Math.max(0, position) : 0
    }

    function millisecondsUntilNextLine(lineIndex) {
        const lines = LyricsService.syncedLines
        if (!lines || lineIndex < 0 || lineIndex >= lines.length)
            return -1

        for (let i = lineIndex + 1; i < lines.length; ++i) {
            if (!lines[i].text || lines[i].text.length === 0)
                continue

            const nextTime = Number(lines[i].time)
            if (isFinite(nextTime))
                return Math.max(0, (nextTime - root.playbackPosition) * 1000)
        }

        return -1
    }

    function transitionDuration(fromIndex, toIndex) {
        if (fromIndex < 0 || toIndex < 0)
            return 0

        const indexJump = Math.abs(toIndex - fromIndex)
        const remainingTime = root.millisecondsUntilNextLine(toIndex)
        if (indexJump >= 4 || remainingTime === 0)
            return 0
        if (indexJump > 1)
            return remainingTime < 0 ? 70 : Math.min(70, Math.floor(remainingTime * 0.25))
        if (remainingTime < 0)
            return 300
        if (remainingTime < 80)
            return 0
        return Math.min(300, Math.floor(remainingTime * 0.5))
    }

    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    onTargetCurrentIndexChanged: {
        if (targetCurrentIndex === lastIndex)
            return

        const previousIndex = lastIndex
        isMovingForward = targetCurrentIndex > previousIndex
        lastIndex = targetCurrentIndex
        scrollAnimation.stop()
        root.scrollDuration = root.transitionDuration(previousIndex, targetCurrentIndex)
        if (root.scrollDuration === 0) {
            root.scrollOffset = 0
            return
        }

        root.scrollOffset = root.isMovingForward ? -root.rowHeight : root.rowHeight
        scrollAnimation.start()
    }

    NumberAnimation {
        id: scrollAnimation
        target: root
        property: "scrollOffset"
        to: 0
        duration: root.scrollDuration
        easing.type: Easing.OutQuart
    }

    Column {
        width: parent.width
        spacing: 0
        y: root.baseY - (root.halfVisibleLines * root.rowHeight) - root.scrollOffset

        Repeater {
            model: root.visibleLineCount

            LyricLine {
                required property int index
                property int lineOffset: index - root.halfVisibleLines
                property int actualIndex: root.targetCurrentIndex + lineOffset
                property bool isValidLine: root.hasSyncedLines && actualIndex >= 0 && actualIndex < LyricsService.syncedLines.length

                gradientDensity: 1 - root.gradientDensity
                defaultLyricsSize: root.defaultLyricsSize
                changeTextWeight: root.changeTextWeight
                textHorizontalAlignment: root.textAlign === "left"  ? Text.AlignLeft  :
                             root.textAlign === "right" ? Text.AlignRight :
                                                          Text.AlignHCenter

                text: isValidLine ? LyricsService.syncedLines[actualIndex].text : (lineOffset === 0 && root.targetCurrentIndex === -1 ? (LyricsService.statusText || "♪") : "")

                // The old line offset maps where this visual line was logically positioned in the previous state.
                property int oldLineOffset: root.isMovingForward ? lineOffset + 1 : lineOffset - 1

                // Highlight animation
                property real targetHighlight: Math.abs(lineOffset) === 0 ? 1.0 : 0.0
                property real startHighlight: Math.abs(oldLineOffset) === 0 ? 1.0 : 0.0
                property real highlightFactor: startHighlight + (targetHighlight - startHighlight) * (1.0 - root.animProgress)

                highlight: highlightFactor > 0.5

                // Opacity animation
                function getOpacityForOffset(offset) {
                    let dist = Math.abs(offset);
                    if (dist === 0)
                        return 1.0;
                    if (dist === 1)
                        return 0.5;
                    if (dist === 2)
                        return 0.2;
                    return 0.0;
                }
                property real targetOpacity: getOpacityForOffset(lineOffset)
                property real startOpacity: getOpacityForOffset(oldLineOffset)
                opacity: startOpacity + (targetOpacity - startOpacity) * (1.0 - root.animProgress)

                // Scale animation
                function getScaleForOffset(offset) {
                    return Math.abs(offset) === 0 ? 1.0 : root.downScale;
                }
                property real targetScale: getScaleForOffset(lineOffset)
                property real startScale: getScaleForOffset(oldLineOffset)
                scale: startScale + (targetScale - startScale) * (1.0 - root.animProgress)

                useGradient: highlightFactor <= 0.5 && root.useGradientMask
                gradientDirection: lineOffset < 0 ? "top" : "bottom"
            }
        }
    }
}
