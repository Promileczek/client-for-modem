import SwiftUI

/// Klawiatura numeryczna w stylu telefonu - dzwonienie przez API modemu.
/// Etap 1: sterowanie polaczeniem bez dzwieku (audio idzie przez WebSocket w etapie 2).
struct DialerView: View {
    @EnvironmentObject private var viewModel: ModemViewModel

    @State private var number = ""
    @State private var hideNumber = false

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["*", "0", "#"]
    ]

    private let letters: [String: String] = [
        "2": "ABC", "3": "DEF", "4": "GHI", "5": "JKL",
        "6": "MNO", "7": "PQRS", "8": "TUV", "9": "WXYZ", "0": "+"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.callStatus.isActive {
                    activeCallBanner
                }

                Spacer(minLength: 8)

                Text(number.isEmpty ? " " : number)
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .textSelection(.enabled)

                HStack {
                    Spacer()
                    if !number.isEmpty {
                        Button {
                            number.removeLast()
                        } label: {
                            Image(systemName: "delete.left")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .onLongPressGesture { number = "" }
                    }
                }
                .frame(height: 30)
                .padding(.horizontal, 32)

                keypad

                Toggle(isOn: $hideNumber) {
                    Label("Ukryj moj numer (CLIR)", systemImage: "eye.slash")
                        .font(.subheadline)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)

                callButtons
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Telefon")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.refreshCallStatus()
            }
            .onDisappear {
                // Nie zostawiamy odpytywania w tle, jesli nie ma polaczenia.
                if viewModel.callStatus.isIdle {
                    viewModel.stopCallPolling()
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
        }
    }

    // MARK: - Czesci widoku

    private var activeCallBanner: some View {
        VStack(spacing: 6) {
            Text(viewModel.callStatus.displayState)
                .font(.headline)
            if let active = viewModel.callStatus.number, !active.isEmpty {
                Text(active)
                    .font(.title3.monospacedDigit())
            }
            Text("Dzwiek rozmowy idzie przez modem, nie przez telefon.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.15))
    }

    private var keypad: some View {
        VStack(spacing: 14) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 26) {
                    ForEach(row, id: \.self) { key in
                        DialKey(digit: key, letters: letters[key]) {
                            append(key)
                        }
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    private var callButtons: some View {
        HStack(spacing: 40) {
            if viewModel.callStatus.isRinging {
                Button {
                    Task { await viewModel.answerCall() }
                } label: {
                    CallButtonLabel(icon: "phone.fill", color: .green)
                }
            } else if viewModel.callStatus.isIdle {
                Button {
                    Task {
                        await viewModel.startCall(number: number, hideNumber: hideNumber)
                    }
                } label: {
                    CallButtonLabel(icon: "phone.fill", color: .green)
                }
                .disabled(number.isEmpty)
                .opacity(number.isEmpty ? 0.4 : 1)
            }

            if viewModel.callStatus.isActive {
                Button {
                    Task { await viewModel.endCall() }
                } label: {
                    CallButtonLabel(icon: "phone.down.fill", color: .red)
                }
            }
        }
    }

    private func append(_ key: String) {
        // Przytrzymanie 0 daje +, ale krotkie dotkniecie wpisuje cyfre.
        number.append(key)
    }
}

private struct DialKey: View {
    let digit: String
    let letters: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(digit)
                    .font(.system(size: 30, weight: .regular))
                if let letters {
                    Text(letters)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .background(Color.gray.opacity(0.15), in: Circle())
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct CallButtonLabel: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 28))
            .foregroundStyle(.white)
            .frame(width: 70, height: 70)
            .background(color.gradient, in: Circle())
    }
}
