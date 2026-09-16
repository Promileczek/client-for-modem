import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var viewModel: ModemViewModel

    @State private var showingAPNPrompt = false
    @State private var apnText = ""

    var body: some View {
        NavigationStack {
            List {
                if let profile = profileStore.selectedProfile {
                    Section {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(ProfileColor.color(at: profile.colorIndex).gradient)
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).font(.headline)
                                Text(profile.subtitle)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusDot(isOnline: viewModel.isReachable)
                        }
                    }
                }

                signalSection
                networkSection
                dataSection
                deviceSection
            }
            .navigationTitle("Modem")
            .refreshable { await viewModel.refreshAll() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refreshAll() }
                    } label: {
                        if viewModel.isLoadingStatus {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoadingStatus)
                }
            }
            .alert(
                "Blad",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("APN", isPresented: $showingAPNPrompt) {
                TextField("np. internet", text: $apnText)
                    .textInputAutocapitalization(.never)
                Button("Wlacz dane") {
                    Task { await viewModel.setData(enabled: true, apn: apnText.isEmpty ? nil : apnText) }
                }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Podaj APN operatora albo zostaw puste, zeby uzyc domyslnego.")
            }
        }
    }

    // MARK: - Sekcje

    private var signalSection: some View {
        Section("Sygnal") {
            if let signal = viewModel.status?.signal {
                HStack {
                    SignalBars(bars: signal.bars)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(signal.rssiDBm) dBm")
                            .font(.title3.bold())
                        Text(qualityLabel(signal.quality))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("RSSI \(signal.rssi)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            } else {
                PlaceholderRow(isLoading: viewModel.isLoadingStatus)
            }
        }
    }

    private var networkSection: some View {
        Section("Siec") {
            InfoRow(
                label: "Operator",
                value: viewModel.status?.`operator`?.name ?? "-",
                icon: "network"
            )
            InfoRow(
                label: "Rejestracja",
                value: registrationLabel,
                icon: "checkmark.seal",
                valueColor: viewModel.status?.registration?.registered == true ? .green : .orange
            )
            InfoRow(
                label: "Karta SIM",
                value: viewModel.status?.sim?.status ?? "-",
                icon: "simcard",
                valueColor: viewModel.status?.sim?.ready == true ? .green : .orange
            )
        }
    }

    private var dataSection: some View {
        Section {
            HStack {
                Label("Transmisja danych", systemImage: "antenna.radiowaves.left.and.right")
                Spacer()
                if let data = viewModel.dataStatus {
                    Text(data.dataDisabled ? "Wylaczona" : "Wlaczona")
                        .font(.subheadline.bold())
                        .foregroundStyle(data.dataDisabled ? .red : .green)
                } else {
                    Text("-").foregroundStyle(.secondary)
                }
            }

            if let data = viewModel.dataStatus {
                InfoRow(
                    label: "GPRS",
                    value: data.gprsAttached ? "Dolaczony" : "Odlaczony",
                    icon: "point.3.connected.trianglepath.dotted"
                )

                if data.dataDisabled {
                    Button {
                        apnText = ""
                        showingAPNPrompt = true
                    } label: {
                        Label("Wlacz transmisje danych", systemImage: "play.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Button {
                        Task { await viewModel.setData(enabled: false) }
                    } label: {
                        Label("Wylacz transmisje danych", systemImage: "stop.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        } header: {
            Text("Internet mobilny")
        } footer: {
            if let data = viewModel.dataStatus, !data.pdpContext.isEmpty {
                Text(data.pdpContext)
                    .font(.caption2.monospaced())
            }
        }
    }

    private var deviceSection: some View {
        Section("Urzadzenie") {
            if let info = viewModel.deviceInfo {
                InfoRow(label: "Model", value: info.shortModel, icon: "cpu")
                if !info.manufacturer.isEmpty {
                    InfoRow(label: "Producent", value: info.manufacturer, icon: "building.2")
                }
                InfoRow(label: "Firmware", value: info.firmware, icon: "gearshape.2", monospaced: true)
                InfoRow(label: "IMEI", value: info.imei, icon: "barcode", monospaced: true)
                InfoRow(label: "IMSI", value: info.imsi, icon: "person.text.rectangle", monospaced: true)
            } else {
                PlaceholderRow(isLoading: viewModel.isLoadingStatus)
            }
        }
    }

    private var registrationLabel: String {
        guard let reg = viewModel.status?.registration else { return "-" }
        switch reg.statusCode {
        case 0: return "Niezarejestrowany"
        case 1: return "Siec domowa"
        case 2: return "Szukanie sieci"
        case 3: return "Odmowa rejestracji"
        case 5: return "Roaming"
        default: return reg.status
        }
    }

    private func qualityLabel(_ quality: String) -> String {
        switch quality.lowercased() {
        case "excellent": return "Doskonaly"
        case "good": return "Dobry"
        case "fair", "ok": return "Przecietny"
        case "poor", "bad": return "Slaby"
        default: return quality.capitalized
        }
    }
}

// MARK: - Komponenty

struct StatusDot: View {
    let isOnline: Bool
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isOnline ? "Online" : "Offline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SignalBars: View {
    let bars: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(level <= bars ? barColor : Color.gray.opacity(0.25))
                    .frame(width: 5, height: CGFloat(6 + level * 4))
            }
        }
        .frame(height: 30, alignment: .bottom)
        .padding(.trailing, 6)
    }

    private var barColor: Color {
        switch bars {
        case 0...1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var valueColor: Color = .primary
    var monospaced: Bool = false

    var body: some View {
        HStack {
            if let icon {
                Label(label, systemImage: icon)
            } else {
                Text(label)
            }
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .font(monospaced ? .caption.monospaced() : .subheadline)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct PlaceholderRow: View {
    let isLoading: Bool
    var body: some View {
        HStack {
            if isLoading {
                ProgressView().controlSize(.small)
                Text("Pobieranie danych...").foregroundStyle(.secondary)
            } else {
                Text("Brak danych. Pociagnij w dol, zeby odswiezyc.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }
}
