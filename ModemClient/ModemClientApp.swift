import SwiftUI

@main
struct ModemClientApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var viewModel = ModemViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(viewModel)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var viewModel: ModemViewModel
    @State private var showingOnboarding = false

    var body: some View {
        Group {
            if profileStore.hasProfiles {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            viewModel.setProfile(profileStore.selectedProfile)
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

            ProfileListView()
                .tabItem { Label("Profile", systemImage: "person.2.fill") }
        }
        .task {
            viewModel.setProfile(profileStore.selectedProfile)
            await viewModel.refreshAll()
        }
    }
}
