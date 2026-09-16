import Foundation
import SwiftUI

/// Przechowuje profile modemow i pamieta, ktory jest aktywny.
/// Odpowiednik listy kont w Zoiperze.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [ModemProfile] = []
    @Published var selectedProfileID: UUID?

    /// Klucze sa wspoldzielone z zadaniem w tle, ktore czyta te same dane
    /// bez tworzenia instancji ProfileStore.
    fileprivate static let profilesKey = "modem.profiles.v1"
    fileprivate static let selectedKey = "modem.selectedProfile.v1"

    private var profilesKey: String { Self.profilesKey }
    private var selectedKey: String { Self.selectedKey }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var selectedProfile: ModemProfile? {
        guard let selectedProfileID else { return profiles.first }
        return profiles.first { $0.id == selectedProfileID } ?? profiles.first
    }

    var hasProfiles: Bool { !profiles.isEmpty }

    // MARK: - Operacje

    func add(_ profile: ModemProfile) {
        profiles.append(profile)
        // Pierwszy dodany profil od razu staje sie aktywny.
        if selectedProfileID == nil {
            selectedProfileID = profile.id
        }
        persist()
    }

    func update(_ profile: ModemProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        persist()
    }

    func delete(_ profile: ModemProfile) {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        let removed = offsets.map { profiles[$0] }
        profiles.remove(atOffsets: offsets)
        if let selected = selectedProfileID, removed.contains(where: { $0.id == selected }) {
            selectedProfileID = profiles.first?.id
        }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func select(_ profile: ModemProfile) {
        selectedProfileID = profile.id
        persist()
    }

    // MARK: - Dostep spoza SwiftUI

    /// Odczytuje aktywny profil prosto z UserDefaults.
    /// Zadanie w tle startuje bez zywej instancji ProfileStore z widokow,
    /// wiec potrzebuje wlasnej sciezki do tych danych.
    static func sharedSelectedProfile(defaults: UserDefaults = .standard) -> ModemProfile? {
        guard let data = defaults.data(forKey: profilesKey),
              let profiles = try? JSONDecoder().decode([ModemProfile].self, from: data),
              !profiles.isEmpty
        else { return nil }

        if let raw = defaults.string(forKey: selectedKey),
           let uuid = UUID(uuidString: raw),
           let match = profiles.first(where: { $0.id == uuid }) {
            return match
        }
        return profiles.first
    }

    // MARK: - Trwalosc

    private func load() {
        if let data = defaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([ModemProfile].self, from: data) {
            profiles = decoded
        }
        if let raw = defaults.string(forKey: selectedKey), let uuid = UUID(uuidString: raw) {
            selectedProfileID = uuid
        }
        // Gdyby zapisany wybor wskazywal na usuniety profil.
        if let id = selectedProfileID, !profiles.contains(where: { $0.id == id }) {
            selectedProfileID = profiles.first?.id
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: profilesKey)
        }
        defaults.set(selectedProfileID?.uuidString, forKey: selectedKey)
    }
}

/// Kolory etykiet profili - wybierane przy tworzeniu profilu.
enum ProfileColor {
    static let all: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .red, .indigo
    ]

    static let names: [String] = [
        "Niebieski", "Zielony", "Pomaranczowy", "Fioletowy",
        "Rozowy", "Turkusowy", "Czerwony", "Indygo"
    ]

    static func color(at index: Int) -> Color {
        all[max(0, min(index, all.count - 1))]
    }
}
