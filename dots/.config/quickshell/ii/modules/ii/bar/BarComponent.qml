import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.ii.bar.weather

import qs.modules.ii.verticalBar as Vertical

Item {
    id: rootItem

    property int barSection // 0: left, 1: center, 2: right
    property var list
    required property var modelData
    required property int index
    property var originalIndex: index
    property bool vertical: false
    property bool highlighted: false
    property bool persistVisibility: true
    property var screen: rootItem.QsWindow.window?.screen
    readonly property int activeWorkspaceId: HyprlandData.monitors.find(monitor => monitor.name === screen?.name)?.activeWorkspace?.id ?? 1
    property real parallaxWorkspaceValue: Appearance.barWorkspaceValue(activeWorkspaceId)
    property real parallaxSidebarBalance: GlobalStates.effectiveRightOpen - GlobalStates.effectiveLeftOpen
    readonly property real screenCenterX: {
        width;
        x;
        let ancestor = parent;
        while (ancestor) {
            ancestor.x;
            ancestor.width;
            ancestor = ancestor.parent;
        }
        return mapToItem(null, width / 2, 0).x;
    }
    readonly property var adaptivePalette: Appearance.colors.transparentBar
        ? Appearance.barPaletteAt(screenCenterX, width, screen, parallaxWorkspaceValue, parallaxSidebarBalance)
        : ({ foreground: Appearance.colors.colOnLayer1 })
    property color foregroundColor: Appearance.colors.transparentBar ? adaptivePalette.foreground : Appearance.colors.colOnLayer1

    implicitWidth: wrapper.implicitWidth
    implicitHeight: wrapper.implicitHeight

    function toggleVisible(visibility) {
        visible = visibility
        if (!persistVisibility) return;
        if (barSection == 0) Config.options.bar.layouts.left[originalIndex].visible = visibility
        else if (barSection == 1) Config.options.bar.layouts.center[originalIndex].visible = visibility
        else if (barSection == 2) Config.options.bar.layouts.right[originalIndex].visible = visibility
    }

    function toggleHighlight(highlight) {
        rootItem.highlighted = highlight
    }

    property var compMap: ({ // [horizontal, vertical]
        "workspaces": [workspaceComp,workspaceComp],
        "music_player": [musicPlayerComp, musicPlayerCompVert],
        "system_monitor": [systemMonitorComp, systemMonitorCompVert],
        "clock": [clockComp, clockCompVert],
        "battery": [batteryComp, batteryCompVert],
        "utility_buttons": [utilityButtonsComp, utilityButtonsComp],
        "system_tray": [systemTrayComp, systemTrayComp],
        "active_window": [activeWindowComp, activeWindowComp],
        "date": [dateCompVert, dateCompVert],
        "record_indicator": [recordIndicatorComp, recordIndicatorComp],
        "screen_share_indicator": [screenshareIndicatorComp, screenshareIndicatorComp],
        "timer": [timerComp, timerCompVert],
        "weather": [weatherComp, weatherComp],
        "policies_panel_button": [policiesPanelButton, policiesPanelButton],
        "dashboard_panel_button": [dashboardPanelButton, dashboardPanelButtonVert],
        "network_speed": [networkSpeedComp, networkSpeedComp],
        "bongocat": [bongoCatComp, bongoCatComp],
    })

    property real startRadius: {
        if (barSection === 0) {
            if (originalIndex == 0) return Appearance.rounding.full
            return Appearance.rounding.verysmall
        } else if (barSection === 2) {
            let hasVisibleLeft = list.slice(0, originalIndex).some(item => item.visible !== false)
            return hasVisibleLeft ? Appearance.rounding.verysmall : Appearance.rounding.full
        } else { // barSection 1 
            if (list.length === 1) return Appearance.rounding.full
            let hasVisibleLeft = list.slice(0, originalIndex).some(item => item.visible !== false)
            return hasVisibleLeft ? Appearance.rounding.verysmall : Appearance.rounding.full
        }
    }

    property real endRadius: {
        if (barSection === 2) {
            if (originalIndex == list.length - 1) return Appearance.rounding.full
            return Appearance.rounding.verysmall
        } else if (barSection === 0) {
            let hasVisibleRight = list.slice(originalIndex + 1).some(item => item.visible !== false)
            return hasVisibleRight ? Appearance.rounding.verysmall : Appearance.rounding.full
        } else { // barSection 1 
            if (list.length === 1) return Appearance.rounding.full
            let hasVisibleRight = list.slice(originalIndex + 1).some(item => item.visible !== false)
            return hasVisibleRight ? Appearance.rounding.verysmall : Appearance.rounding.full
        }
    }

    readonly property int barGroupStyle: Config.options.bar.barGroupStyle
    readonly property int barBackgroundStyle: Config.options.bar.barBackgroundStyle
    readonly property color baseBackground: barGroupStyle == 0 ? Appearance.colors.colLayer1 :
                                                (barGroupStyle == 1 && barBackgroundStyle == 1) ? Appearance.colors.colLayer1 :
                                                (barGroupStyle == 1) ? Appearance.m3colors.m3surfaceContainerLow :
                                                "transparent"
    property color colBackground: rootItem.baseBackground
    
    property color colBackgroundHighlight: Appearance.colors.colPrimary

    BarGroup {
        id: wrapper
        vertical: rootItem.vertical
        anchors {
            verticalCenter: rootItem.vertical ? rootItem.verticalCenter : undefined
            horizontalCenter: rootItem.vertical ? undefined : rootItem.horizontalCenter
        }
        
        startRadius: rootItem.startRadius
        endRadius: rootItem.endRadius
        colBackground: rootItem.highlighted ? rootItem.colBackgroundHighlight : rootItem.colBackground

        readonly property var _currentComp: {
            BarComponentRegistry._extensionCompVersion
            let builtin = compMap[modelData.id]
            if (builtin) return builtin[vertical ? 1 : 0]
            return BarComponentRegistry.getComponentForId(modelData.id, vertical)
        }

        Loader {
            id: itemLoader
            active: true
            sourceComponent: wrapper._currentComp
            onLoaded: {
                let extId = BarComponentRegistry.getExtensionIdForComponent(modelData.id)
                if (extId && item) {
                    if ("extensionId" in item) {
                        item.extensionId = extId
                    } else {
                        Object.defineProperty(item, "extensionId", {
                            value: extId,
                            writable: true,
                            configurable: true,
                            enumerable: true
                        })
                    }
                }
            }
        }
    }


    Component { id: weatherComp; WeatherBar { vertical: rootItem.vertical; foregroundColor: rootItem.foregroundColor } }

    Component { id: timerComp; TimerWidget {} }
    Component { id: timerCompVert; Vertical.VerticalTimerWidget {} }

    Component { id: screenshareIndicatorComp; ScreenShareIndicator {} }

    Component { id: recordIndicatorComp; RecordIndicator { vertical: rootItem.vertical } }

    Component { id: activeWindowComp; ActiveWindow { vertical: rootItem.vertical; foregroundColor: rootItem.foregroundColor } }

    Component { id: systemMonitorComp; Resources { foregroundColor: rootItem.foregroundColor; screen: rootItem.screen; parallaxWorkspaceValue: rootItem.parallaxWorkspaceValue; parallaxSidebarBalance: rootItem.parallaxSidebarBalance } }
    Component { id: systemMonitorCompVert; Vertical.Resources {} }

    Component { id: musicPlayerCompVert; Vertical.VerticalMedia {} }
    Component { id: musicPlayerComp; Media { foregroundColor: rootItem.foregroundColor } }

    Component { id: utilityButtonsComp; UtilButtons { vertical: rootItem.vertical; foregroundColor: rootItem.foregroundColor; containerScreenCenterX: rootItem.screenCenterX; screen: rootItem.screen; parallaxWorkspaceValue: rootItem.parallaxWorkspaceValue; parallaxSidebarBalance: rootItem.parallaxSidebarBalance } }

    Component { id: batteryComp; BatteryIndicator { foregroundColor: rootItem.foregroundColor } }
    Component { id: batteryCompVert; Vertical.BatteryIndicator {} }

    Component { id: clockCompVert; Vertical.VerticalClockWidget {} }
    Component { id: clockComp; ClockWidget { foregroundColor: rootItem.foregroundColor } }

    Component { id: systemTrayComp; SysTray { vertical: rootItem.vertical; foregroundColor: rootItem.foregroundColor } }

    Component { id: dateCompVert; Vertical.VerticalDateWidget {} }

    Component { id: workspaceComp; Workspaces { vertical: rootItem.vertical; foregroundColor: rootItem.foregroundColor; screen: rootItem.screen; parallaxWorkspaceValue: rootItem.parallaxWorkspaceValue; parallaxSidebarBalance: rootItem.parallaxSidebarBalance } }

    Component { id: policiesPanelButton; PoliciesPanelButton { foregroundColor: rootItem.foregroundColor } }
    
    Component { id: dashboardPanelButton; DashboardPanelButton { foregroundColor: rootItem.foregroundColor } }
    Component { id: networkSpeedComp; NetworkSpeed { vertical: rootItem.vertical; foregroundColor: rootItem.foregroundColor } }
    Component { id: bongoCatComp; BongoCatWidget { vertical: rootItem.vertical } }
    Component { id: dashboardPanelButtonVert; VerticalDashboardPanelButton {} }
}
