import QtQuick
import Quickshell
import qs.modules.ii.sidebarDashboard.pomodoro

ShellRoot {
    Loader {
        id: widgetLoader
        width: 332
        height: 350
        sourceComponent: PomodoroWidget {
            width: 332
            height: 350
        }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            if (widgetLoader.status !== Loader.Ready || !widgetLoader.item) Qt.exit(2);
            console.log("[PomodoroUiCheck] ready=332x350");
            Qt.quit();
        }
    }
}
