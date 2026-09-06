import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.sidebarPolicies

ShellRoot {
    Component { id: metrics; SystemGlance {} }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!Config.ready) return;
            stop();
            function check(condition, message) {
                if (!condition) throw new Error(message);
            }
            try {
                let calls = 0;
                const rejected = (ok, result, error) => {
                    check(!ok && !!error?.message, "missing failure reason");
                    calls++;
                };
                NetworkProfiles.operationRunning = true;
                NetworkProfiles.createProfile({}, rejected);
                NetworkProfiles.updateProfile({}, rejected);
                NetworkProfiles.deleteProfile({}, rejected);
                NetworkProfiles.activateProfile({}, rejected);
                check(calls === 4 && NetworkProfiles.operationRunning, "busy write callback/state");
                NetworkProfiles.pendingRequests = { test: { callback: rejected } };
                NetworkProfiles.failPending("");
                NetworkProfiles.failPending("");
                check(calls === 5, "pending callback must run exactly once");
                NetworkProfiles.pendingRequests = { test: { callback: rejected } };
                NetworkProfiles.stop();
                check(calls === 6 && !NetworkProfiles.operationRunning, "stop cleanup");
                GlobalStates.overviewOpen = true;
                const baseline = ResourceUsage.activeInstances;
                const panel = metrics.createObject(null);
                panel.launcherMode = true;
                check(ResourceUsage.activeInstances === baseline + 1, "mode switch did not subscribe");
                panel.launcherMode = false;
                check(ResourceUsage.activeInstances === baseline, "mode switch leaked subscription");
                check(panel.formatGB(1048576) === "1.0 GiB", "binary unit");
                const forecast = [{ time: "900" }, { time: "1200" }, { time: "1500" }];
                check(panel.getUpcomingForecast(forecast, 12)[0].time === "1200", "forecast slot");
                check(panel.getUpcomingForecast(null, 12).length === 0, "missing forecast");
                panel.destroy();
                console.log("PASS: busy callbacks, stop errors, resource tracking, forecast, GiB");
                Qt.exit(0);
            } catch (error) {
                console.error(error);
                Qt.exit(1);
            }
        }
    }
}
