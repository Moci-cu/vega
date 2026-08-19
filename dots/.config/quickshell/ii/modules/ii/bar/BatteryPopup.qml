import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import "./cards"

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    function formatTime(seconds) {
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        if (h > 0)
            return `${h}h, ${m}m`;
        else
            return `${m}m`;
    }

    function stateText() {
        if (Battery.chargeState == 4)
            return Translation.tr("Fully charged");
        if (Battery.isCharging)
            return Translation.tr("Charging at %1 W").arg(Math.abs(Battery.energyRate).toFixed(2));
        return Translation.tr("Using %1 W").arg(Math.abs(Battery.energyRate).toFixed(2));
    }

    function remainingTimeText() {
        if (Battery.chargeState == 4)
            return Translation.tr("Ready to unplug");
        if (Battery.isCharging) {
            if (Battery.timeToFull > 0)
                return Translation.tr("%1 until full").arg(root.formatTime(Battery.timeToFull));
            return Translation.tr("Calculating time to full");
        }
        if (Battery.timeToEmpty > 0)
            return Translation.tr("%1 remaining").arg(root.formatTime(Battery.timeToEmpty));
        return Translation.tr("Estimating remaining time");
    }

    readonly property bool lowBattery: Battery.isLow && !Battery.isCharging
    readonly property color cardContainerColor: lowBattery
        ? Appearance.colors.colErrorContainer
        : Battery.isCharging
            ? Appearance.colors.colTertiaryContainer
            : Appearance.colors.colSecondaryContainer
    readonly property color cardAccentColor: lowBattery
        ? Appearance.m3colors.m3error
        : Battery.isCharging
            ? Appearance.colors.colTertiary
            : Appearance.colors.colSecondary
    readonly property color cardOnContainerColor: lowBattery
        ? Appearance.colors.colOnErrorContainer
        : Battery.isCharging
            ? Appearance.colors.colOnTertiaryContainer
            : Appearance.colors.colOnSecondaryContainer
    readonly property color cardOnAccentColor: lowBattery
        ? Appearance.colors.colOnError
        : Battery.isCharging
            ? Appearance.colors.colOnTertiary
            : Appearance.colors.colOnSecondary

    animate: false
    contentItem: ExpressiveMetricCard {
        id: batteryHero
        anchors.centerIn: parent

        label: Translation.tr("Battery level")
        value: `${Math.round(Battery.percentage * 100)}%`
        supportingText: root.stateText()
        detailText: root.remainingTimeText()
        detailIcon: Battery.isCharging ? "bolt" : "schedule"
        badgeText: Battery.health > 0
            ? Translation.tr("Health %1%").arg(Math.round(Battery.health))
            : ""
        badgeIcon: "health_metrics"
        icon: root.lowBattery
            ? "battery_alert"
            : Battery.isCharging
                ? "battery_charging_full"
                : "battery_android_full"
        progress: Battery.percentage
        shapeString: Battery.isCharging ? "Flower" : "Puffy"

        containerColor: root.cardContainerColor
        accentColor: root.cardAccentColor
        shapeColor: root.cardAccentColor
        symbolColor: root.cardOnAccentColor
        textColor: root.cardOnContainerColor
        mutedTextColor: root.cardOnContainerColor
        badgeColor: Appearance.colors.colSurfaceContainerHighest
        badgeTextColor: Appearance.m3colors.m3onSurface
    }
}
