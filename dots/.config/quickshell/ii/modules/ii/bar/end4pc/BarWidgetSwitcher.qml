import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property bool isMaterial: true
    property real horizontalExtraPadding: 12

    property Component colDefault
    property Component colMaterial
    property Component rowDefault
    property Component rowMaterial

    implicitWidth: root.vertical
        ? 32
        : (rowLoader.item?.implicitWidth ?? 0) + (root.isMaterial ? 0 : root.horizontalExtraPadding)
    implicitHeight: root.vertical
        ? (colLoader.item?.implicitHeight ?? 0)
        : 40

    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? root.colMaterial : root.colDefault
    }

    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? root.rowMaterial : root.rowDefault
    }
}
