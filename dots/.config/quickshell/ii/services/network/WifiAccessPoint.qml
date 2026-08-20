import QtQuick
import Quickshell.Networking

QtObject {
    id: root
    required property var backendNetwork
    property var failureHandler: null

    readonly property string ssid: backendNetwork?.name ?? ""
    // Quickshell's networking API does not currently expose these scan fields.
    readonly property string bssid: ""
    readonly property int strength: Math.round((backendNetwork?.signalStrength ?? 0) * 100)
    readonly property int frequency: 0
    readonly property bool active: backendNetwork?.connected ?? false
    readonly property int securityType: backendNetwork?.security ?? WifiSecurityType.Unknown
    readonly property string security: securityType === WifiSecurityType.Open
        ? ""
        : WifiSecurityType.toString(securityType)
    readonly property bool isSecure: securityType !== WifiSecurityType.Open
    readonly property bool supportsPsk: securityType === WifiSecurityType.WpaPsk
        || securityType === WifiSecurityType.Wpa2Psk
        || securityType === WifiSecurityType.Sae

    property bool askingPassword: false
    property bool passwordAttemptPending: false

    property Connections connectionWatcher: Connections {
        target: root.backendNetwork

        function onConnectionFailed(reason) {
            if (root.failureHandler) root.failureHandler(root, reason)
        }
    }
}
