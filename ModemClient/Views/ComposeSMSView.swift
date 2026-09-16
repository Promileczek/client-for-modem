import SwiftUI

struct ComposeSMSView: View {
    @EnvironmentObject private var viewModel: ModemViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var number: String
    @State private var text: String = ""
    @State private var isSending = false
    @FocusState private var focusedField: Field?

    private enum Field { case number, text }

    init(prefilledNumber: String = "") {
        _number = State(initialValue: prefilledNumber)
    }

    /// SMS w GSM-7 miesci 160 znakow; ze znakami spoza tablicy modem
    /// przechodzi na UCS-2, gdzie limit to 70 znakow.
    private var isUnicode: Bool {
        text.unicodeScalars.contains { $0.value > 127 }
    }

    private var characterLimit: Int { isUnicode ? 70 : 160 }

    private var partCount: Int {
        guard !text.isEmpty else { return 0 }
        let perPart = isUnicode ? 67 : 153
        return text.count <= characterLimit ? 1 : Int(ceil(Double(text.count) / Double(perPart)))
    }

    private var canSend: Bool {
        !number.trimmingCharacters(in: .whitespaces).isEmpty
            && !text.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Odbiorca") {
                    TextField("+48123456789", text: $number)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .number)
                }

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .focused($focusedField, equals: .text)
                } header: {
                    Text("Tresc")
                } footer: {
                    HStack {
                        Text("\(text.count) znakow")
                        if partCount > 1 {
                            Text("- \(partCount) czesci")
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(isUnicode ? "UCS-2" : "GSM-7")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                }

                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSending {
                                ProgressView().controlSize(.small)
                                Text("Wysylanie...")
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Wyslij SMS")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSend)
                }
            }
            .navigationTitle("Nowa wiadomosc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
            .onAppear {
                focusedField = number.isEmpty ? .number : .text
            }
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        let success = await viewModel.sendSMS(
            number: number.trimmingCharacters(in: .whitespaces),
            text: text
        )
        if success { dismiss() }
    }
}
