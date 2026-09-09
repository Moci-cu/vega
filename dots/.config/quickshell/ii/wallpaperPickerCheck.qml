import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.wallpaperSelector

ShellRoot {
    Component.onCompleted: GlobalStates.wallpaperSelectorOpen = true
    WallpaperPicker { id: picker }
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            const count = picker.wallpapers.length;
            if (!Wallpapers.isVideoFile("sample.MP4") || !Wallpapers.isVideoFile("sample.m4v")
                    || Wallpapers.isVideoFile("sample.png")) {
                console.error("WallpaperPicker: video classification failed");
                Qt.exit(1);
                return;
            }
            picker.currentIndex = 0;
            picker.navigate(-1);
            if (picker.currentIndex !== (count ? count - 1 : 0)) {
                console.error("WallpaperPicker: backward wrap failed");
                Qt.exit(1);
                return;
            }
            picker.navigate(1);
            if (picker.currentIndex !== 0) {
                console.error("WallpaperPicker: forward wrap failed");
                Qt.exit(1);
                return;
            }
            const videoIndex = picker.wallpapers.findIndex(file => Wallpapers.isVideoFile(file.name));
            if (videoIndex >= 0) picker.currentIndex = videoIndex;
            closePreview.start();
        }
    }
    Timer {
        id: closePreview
        interval: 2000
        onTriggered: {
            picker.currentIndex = 0;
            picker.doClose();
            picker.navigate(1);
            if (picker.currentIndex !== 0) {
                console.error("WallpaperPicker: navigation during close");
                Qt.exit(1);
                return;
            }
            finish.start();
        }
    }
    Timer {
        id: finish
        interval: 1200
        onTriggered: {
            if (!picker.done || GlobalStates.wallpaperSelectorOpen) {
                console.error("WallpaperPicker: closing animation did not finish");
                Qt.exit(1);
                return;
            }
            console.log("PASS: wallpaper picker load, navigation and close; images=" + picker.wallpapers.length);
            Qt.exit(0);
        }
    }
}
