import NetworkExtension

/// DNS layer: Mullvad's free "family" resolver over DNS-over-TLS, for every app on the phone.
/// Saving installs the configuration; the person switches it on in
/// Settings > General > VPN & Device Management > DNS.
@MainActor @Observable
final class DNSManager {
    private(set) var isInstalled = false
    private(set) var isEnabled = false
    var error: String?

    func refresh() async {
        let manager = NEDNSSettingsManager.shared()
        try? await manager.loadFromPreferences()
        isInstalled = manager.dnsSettings != nil
        isEnabled = manager.isEnabled
    }

    func install() async {
        let manager = NEDNSSettingsManager.shared()
        do {
            try await manager.loadFromPreferences()
            let settings = NEDNSOverTLSSettings(servers: ["194.242.2.6", "2a07:e340::6"])
            settings.serverName = "family.dns.mullvad.net"
            manager.dnsSettings = settings
            manager.localizedDescription = "Gamble Guard"
            try await manager.saveToPreferences()
            isInstalled = true
            isEnabled = manager.isEnabled
        } catch {
            self.error = error.localizedDescription
        }
    }
}
