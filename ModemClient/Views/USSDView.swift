import SwiftUI

struct USSDView: View {
    @EnvironmentObject private var viewModel: ModemViewModel

    @State private var code = ""
    @State private var isSending = false
    @State private var response: USSDResponse?
    @State private var saldo: SaldoResponse?
    @State private var isCheckingSaldo = false
    @State private var history: [String] = []

    /// Skroty dzialajace u wiekszosci polskich operatorow.
    private let quickCodes: [(label: String, code: String)] = [
        ("Saldo", "*101#"),
        ("Moj numer", "*102#"),
        ("Pakiety", "*111#"),
        ("Oferta", "*100#")
    ]

    var body: some View {
        NavigationStack {
            List {
                saldoSection
                codeSection
                if let response { responseSection(response) }
                if !history.isEmpty { historySection }
            }
            .navigationTitle("USSD")
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
        }
    }

    // MARK: - Sekcje

    private var saldoSection: some View {
        Section("Stan konta") {
            if let saldo, saldo.ok {
                VStack(alignment: .leading, spacing: 6) {
                    Text(saldo.saldo.isEmpty ? saldo.rawResponse : saldo.saldo)
                        .font(.body)
                        .textSelection(.enabled)
                    if !saldo.`operator`.isEmpty {
                        Text("Operator: \(saldo.`operator`) - kod \(saldo.usedCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                Task { await checkSaldo() }
            } label: {
                HStack {
                    if isCheckingSaldo {
                        ProgressView().controlSize(.small)
                        Text("Sprawdzanie...")
                    } else {
                        Image(systemName: "creditcard")
                        Text("Sprawdz saldo")
                    }
                }
            }
            .disabled(isCheckingSaldo)
        }
    }

    private var codeSection: some View {
        Section {
            HStack {
                TextField("*101#", text: $code)
                    .keyboardType(.phonePad)
                    .autocorrectionDisabled()
                Button {
                    Task { await sendCode(code) }
                } label: {
                    if isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(code.isEmpty || isSending)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickCodes, id: \.code) { item in
                        Button {
                            code = item.code
                            Task { await sendCode(item.code) }
                        } label: {
                            VStack(spacing: 1) {
                                Text(item.label).font(.caption.bold())
                                Text(item.code).font(.caption2.monospaced())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.blue.opacity(0.13), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSending)
                    }
                }
                .padding(.vertical, 3)
            }
        } header: {
            Text("Kod USSD")
        } footer: {
            Text("Modem E160G wysyla kody w kodowaniu GSM-7. Odpowiedz moze zajac kilkanascie sekund.")
        }
    }

    private func responseSection(_ result: USSDResponse) -> some View {
        Section("Odpowiedz sieci") {
            Text(result.response.isEmpty ? result.rawResponse : result.response)
                .font(.body)
                .textSelection(.enabled)
                .padding(.vertical, 2)

            if !result.error.isEmpty {
                Label(result.error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !result.usedCode.isEmpty {
                Text("Kod: \(result.usedCode)  -  kodowanie: \(result.encoding)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var historySection: some View {
        Section("Historia") {
            ForEach(history, id: \.self) { item in
                Button {
                    code = item
                    Task { await sendCode(item) }
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        Text(item).font(.callout.monospaced())
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Akcje

    private func sendCode(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        response = await viewModel.sendUSSD(code: trimmed)
        if response != nil {
            history.removeAll { $0 == trimmed }
            history.insert(trimmed, at: 0)
            if history.count > 8 { history.removeLast() }
        }
    }

    private func checkSaldo() async {
        isCheckingSaldo = true
        defer { isCheckingSaldo = false }
        saldo = await viewModel.fetchSaldo()
    }
}
