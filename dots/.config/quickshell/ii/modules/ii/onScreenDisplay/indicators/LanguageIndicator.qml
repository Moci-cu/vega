import qs.services
import QtQuick
import qs.modules.ii.onScreenDisplay
import qs.modules.common.widgets

OsdValueIndicator {
    id: root

    value: 0
    showProgressBar: false
    icon: "language"
    name: HyprlandXkb.currentLayoutName || "English (US)"
    shape: MaterialShape.Shape.Cookie7Sided
}
