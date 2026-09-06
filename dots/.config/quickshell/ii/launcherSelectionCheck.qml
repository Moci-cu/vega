import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.overview

ShellRoot {
    property int phase: 0
    property int attempts: 0
    SearchWidget {
        id: widget
        showResults: true
        revealProgress: 0
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (++attempts > 150) {
                console.error("Selection test timed out");
                Qt.exit(1);
                return;
            }
            if (!Config.ready || !NativeAppSearch.model?.indexReady) return;
            if (phase === 0) {
                GlobalStates.overviewOpen = true;
                widget.setSearchingText(Config.options.search.prefix.app);
                phase++;
            } else if (phase === 1 || phase === 3) {
                if (!widget.appSelectionReady || widget.activeResultCount < 2) return;
                // Input arriving after completion must survive its deferred callback.
                widget.finishResultsRefresh(widget.searchingText);
                widget.moveSelection(1, true);
                phase++;
            } else if (phase === 2) {
                if (widget.activeCurrentIndex !== 1) {
                    console.error("Deferred refresh overwrote selection");
                    Qt.exit(1);
                    return;
                }
                widget.showClipboard = true;
                widget.setSearchingText(Config.options.search.prefix.clipboard);
                phase = 5;
            } else if (phase === 5) {
                widget.showClipboard = false;
                widget.setSearchingText(Config.options.search.prefix.app);
                phase = 3;
            } else if (phase === 4) {
                if (widget.activeCurrentIndex !== 1) {
                    console.error("Clipboard round trip overwrote selection");
                    Qt.exit(1);
                    return;
                }
                console.log("PASS: deferred refresh preserves selection after clipboard round trip");
                Qt.exit(0);
            }
        }
    }
}
