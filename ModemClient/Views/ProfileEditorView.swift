import SwiftUI

/// Dodawanie i edycja profilu modemu, z testem polaczenia przed zapisem.
struct ProfileEditorView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    private let existingProfile: ModemProfile?

    @State private var name: String
    @State private var host: String
    @State private var portText: String
    @State private var useHTTPS: Bool
    @State private var apiKey: String
    @State private var colorIndex: Int

    @State private var isTesting = false
    @State private var testResult: TestResult?

    private enum TestResult {
        case success(String)
        case failure(String)
    }

    init(profile: ModemProfile?) {
        self.existingProfile = profile
        _name = State(initialValue: profile?.name ?? "")
        _host = State(initialValue: profile?.host ?? "")
        _portText = State(initialValue: String(profile?.port ?? 7500))
        _useHTTPS = State(initialValue: profile?.useHTTPS ?? false)
        _apiKey = State(initialValue: profile?.apiKey ?? "")
        _colorIndex = State(initialValue: profile?.colorIndex ?? 0)
    }

    private var port: Int { Int(portText) ?? 0 }

    private var draftProfile: ModemProfile {
        ModemProfile(
            id: existingProfile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: port,
            useHTTPS: useHTTPS,
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            colorIndex: colorIndex
        )
    }

    private var canSave: Bool { draftProfile.isValid }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nazwa profilu") {
                    TextField("np. Modem domowy", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    TextField("192.168.0.119", text: $host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("7500", text: $portText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }

                    Toggle("Uzyj HTTPS", isOn: $useHTTPS)
                } header: {
                    Text("Adres serwera API")
                } footer: {
                    Text("Adres: \(draftProfile.scheme)://\(host.isEmpty ? "..." : host):\(portText)")
                        .font(.caption.monospaced())
                }

                Section {
                    SecureField("Puste = brak", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Klucz API (opcjonalny)")
                } footer: {
                    Text("Wysylany jako naglowek X-API-Key. Zostaw puste, jesli serwer nie wymaga autoryzacji.")
                }

                Section("Kolor etykiety") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(ProfileColor.all.indices, id: \.self) { index in
                                Circle()
                                    .fill(ProfileColor.color(at: index).gradient)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if index == colorIndex {
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: 3)
                                        }
                                    }
                                    .onTapGesture { colorIndex = index }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "bolt.horizontal.circle")
                            }
                            Text(isTesting ? "Testowanie..." : "Testuj polaczenie")
                        }
                    }
                    .disabled(!canSave || isTesting)

                    if let testResult {
                        switch testResult {
                        case .success(let text):
                            Label(text, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.callout)
                        case .failure(let text):
                            Label(text, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.callout)
                        }
                    }
                }
            }
            .navigationTitle(existingProfile == nil ? "Nowy profil" : "Edytuj profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }
        do {
            let status = try await ModemAPI.shared.testConnection(profile: draftProfile)
            let operatorName = status.operator?.name ?? "nieznany"
            let signal = status.signal.map { "\($0.rssiDBm) dBm" } ?? "brak danych"
            testResult = .success("Polaczono. Operator: \(operatorName), sygnal: \(signal)")
        } catch {
            let message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            testResult = .failure(message)
        }
    }

    private func save() {
        let profile = draftProfile
        if existingProfile == nil {
            profileStore.add(profile)
        } else {
            profileStore.update(profile)
        }
        dismiss()
    }
}
