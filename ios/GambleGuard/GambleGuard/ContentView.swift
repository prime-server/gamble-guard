import FamilyControls
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = GuardModel()
    @State private var dns = DNSManager()
    @State private var pickingApps = false

    private var allDone: Bool { model.isAuthorized && dns.isEnabled && model.isLocked }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(allDone ? "Congratulations. You will never gamble again."
                                 : "Three steps. After the third, this phone does not gamble.")
                        .font(.title2.bold())
                        .padding(.vertical, 8)
                }

                Section {
                    StepRow(number: 1, title: "Authorize Screen Time", done: model.isAuthorized,
                            detail: model.isAuthorized
                                ? "\(model.blockedDomainCount) gambling sites and Apple's adult-content filter are blocked in every browser on this phone."
                                : "Blocks gambling sites in every browser on this phone, right now, together with Apple's adult-content filter.")
                    if model.isAuthorized {
                        Button("Choose gambling apps to block…") { pickingApps = true }
                            .familyActivityPicker(isPresented: $pickingApps, selection: $model.selection)
                            .onChange(of: model.selection) { model.applyShields() }
                    } else {
                        Button("Authorize") { Task { await model.authorize() } }
                    }
                }

                Section {
                    StepRow(number: 2, title: "Turn on DNS protection", done: dns.isEnabled,
                            detail: "Mullvad's family DNS refuses to resolve gambling domains for every app, not only browsers.")
                    if dns.isInstalled, !dns.isEnabled {
                        Text("Settings → General → VPN & Device Management → DNS → Gamble Guard.")
                    } else if !dns.isInstalled {
                        Button("Add Mullvad DNS") { Task { await dns.install() } }
                    }
                }

                Section {
                    StepRow(number: 3, title: "Lock it", done: model.isLocked,
                            detail: "Delete any VPN app first. Lock turns off Deleting Apps for the whole phone, this app included. Then Settings → Screen Time → Lock Screen Time Settings: another person types the passcode and keeps it. Settings → Apple Account → iCloud → Private Relay → Off.")
                    if !model.isLocked {
                        Button("Lock") { model.lock() }
                            .disabled(!model.isAuthorized)
                    }
                }

                if let error = model.error ?? dns.error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Gamble Guard")
            .task { model.refresh(); await dns.refresh() }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    model.refresh()
                    Task { await dns.refresh() }
                }
            }
        }
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let done: Bool
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .font(.largeTitle)
                .foregroundStyle(done ? .green : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
