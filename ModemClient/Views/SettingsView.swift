import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var notifications: NotificationService

    @State private var notificationsEnabled = NotificationService.shared.notificationsEnabled

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileListView()
                    } label: {
                        HStack {
                            Label("Profile modemow", systemImage: "person.2.fill")
                            Spacer()
                            Text("\(profileStore.profiles.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                notificationSection
                aboutSection
            }
            .navigationTitle("Ustawienia")
            .task { await notifications.refreshAuthorizationStatus() }
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label("Powiadomienia", systemImage: "bell.fill")
            }
            .onChange(of: notificationsEnabled) { newValue in
                NotificationService.shared.notificationsEnabled = newValue
                if newValue && !notifications.isAuthorized {
                    Task { await notifications.requestAuthorization() }
                }
            }

            if !notifications.isAuthorized {
                Button {
                    openSystemSettings()
                } label: {
                    Label("Wlacz zgode w Ustawieniach iOS", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Powiadomienia")
        } footer: {
            Text("""
            Aplikacja powiadamia o nowych SMS-ach i polaczeniach przychodzacych.

            Gdy jest otwarta, sprawdza modem co kilka sekund. Po zamknieciu \
            korzysta z odswiezania w tle, o ktorego terminie decyduje iOS - \
            moze to byc co kilkanascie minut albo rzadziej. Natychmiastowych \
            powiadomien przy zamknietej aplikacji nie da sie uzyskac bez \
            platnego konta Apple Developer.
            """)
        }
    }

    private var aboutSection: some View {
        Section("O aplikacji") {
            InfoRow(label: "Wersja", value: appVersion, icon: "info.circle")
            InfoRow(label: "Etap", value: "1 - bez audio rozmow", icon: "waveform")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
