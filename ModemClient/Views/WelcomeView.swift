import SwiftUI

/// Ekran powitalny pokazywany, gdy nie ma jeszcze zadnego profilu.
struct WelcomeView: View {
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue.gradient)

                VStack(spacing: 10) {
                    Text("Klient modemu")
                        .font(.largeTitle.bold())
                    Text("Zarzadzaj modemem GSM przez API -\nSMS, polaczenia, USSD i transmisja danych.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Dodaj pierwszy profil", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Potrzebujesz adresu IP i portu serwera API modemu,\nnp. 192.168.0.119:7500")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
            .sheet(isPresented: $showingEditor) {
                ProfileEditorView(profile: nil)
            }
        }
    }
}
