import SwiftUI

struct ProfileListView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var viewModel: ModemViewModel

    @State private var editingProfile: ModemProfile?
    @State private var showingNewProfile = false
    @State private var profileToDelete: ModemProfile?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(profileStore.profiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isSelected: profile.id == profileStore.selectedProfile?.id,
                            isReachable: profile.id == profileStore.selectedProfile?.id
                                ? viewModel.isReachable : nil
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            profileStore.select(profile)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                profileToDelete = profile
                            } label: {
                                Label("Usun", systemImage: "trash")
                            }
                            Button {
                                editingProfile = profile
                            } label: {
                                Label("Edytuj", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { profileStore.move(from: $0, to: $1) }
                } header: {
                    Text("Zapisane profile")
                } footer: {
                    Text("Dotknij profil, zeby go aktywowac. Przesun w lewo, zeby edytowac lub usunac.")
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingNewProfile) {
                ProfileEditorView(profile: nil)
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditorView(profile: profile)
            }
            .confirmationDialog(
                "Usunac profil \"\(profileToDelete?.name ?? "")\"?",
                isPresented: Binding(
                    get: { profileToDelete != nil },
                    set: { if !$0 { profileToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Usun profil", role: .destructive) {
                    if let profileToDelete {
                        profileStore.delete(profileToDelete)
                    }
                    profileToDelete = nil
                }
                Button("Anuluj", role: .cancel) { profileToDelete = nil }
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: ModemProfile
    let isSelected: Bool
    /// nil = nieznany stan (profil nieaktywny).
    let isReachable: Bool?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ProfileColor.color(at: profile.colorIndex).gradient)
                    .frame(width: 42, height: 42)
                Image(systemName: "simcard.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.headline)
                    if let isReachable {
                        Circle()
                            .fill(isReachable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(profile.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}
