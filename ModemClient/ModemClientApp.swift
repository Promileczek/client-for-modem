import SwiftUI

@main
struct ModemClientApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var viewModel = ModemViewModel()
    @StateObject private var notifications = NotificationService.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Rejestracja musi nastapic zanim aplikacja skonczy sie uruchamiac,
        // inaczej system zglasza wyjatek przy pierwszym zaplanowaniu zadania.
        BackgroundRefreshService.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(viewModel)
                .environmentObject(notifications)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                Task {
                    await notifications.refreshAuthorizationStatus()
                    await notifications.clearBadge()
                }
                viewModel.startForegroundPolling()

            case .background:
                // Odpytywanie na pierwszym planie nie ma sensu w tle,
                // a iOS i tak zaraz zamrozi aplikacje.
                viewModel.stopForegroundPolling()
                viewModel.stopCallPolling()
                BackgroundRefreshService.schedule()

            case .inactive:
                break

            @unknown default:
                break
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var viewModel: ModemViewModel
    @EnvironmentObject private var notifications: NotificationService

    var body: some View {
        Group {
            if profileStore.hasProfiles {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .task {
            viewModel.setProfile(profileStore.selectedProfile)
            await notifications.refreshAuthorizationStatus()
            // O zgode pytamy dopiero, gdy jest jakis modem do obserwowania.
            if profileStore.hasProfiles && !notifications.isAuthorized {
                await notifications.requestAuthorization()
            }
        }
        .onChange(of: profileStore.selectedProfileID) { _ in
            viewModel.setProfile(profileStore.selectedProfile)
            Task { await viewModel.refreshAll() }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var viewModel: ModemViewModel

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Modem", systemImage: "antenna.radiowaves.left.and.right") }

            SMSListView()
                .tabItem { Label("SMS", systemImage: "message.fill") }

            DialerView()
                .tabItem { Label("Telefon", systemImage: "phone.fill") }

            USSDView()
                .tabItem { Label("USSD", systemImage: "number.square.fill") }

            SettingsView()
                .tabItem { Label("Ustawienia", systemImage: "gearshape.fill") }
        }
        .task {
            viewModel.setProfile(profileStore.selectedProfile)
            await viewModel.refreshAll()
            viewModel.startForegroundPolling()
        }
    }
}
