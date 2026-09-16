import SwiftUI

struct SMSListView: View {
    @EnvironmentObject private var viewModel: ModemViewModel

    @State private var filter: SMSFilter = .all
    @State private var showingCompose = false
    @State private var searchText = ""

    enum SMSFilter: String, CaseIterable {
        case all = "ALL"
        case unread = "REC UNREAD"
        case read = "REC READ"
        case sent = "STO SENT"

        var label: String {
            switch self {
            case .all: return "Wszystkie"
            case .unread: return "Nieprzeczytane"
            case .read: return "Przeczytane"
            case .sent: return "Wyslane"
            }
        }
    }

    private var filteredMessages: [SMSMessage] {
        guard !searchText.isEmpty else { return viewModel.messages }
        let needle = searchText.lowercased()
        return viewModel.messages.filter {
            $0.text.lowercased().contains(needle)
                || $0.sender.lowercased().contains(needle)
                || $0.senderName.lowercased().contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.messages.isEmpty && !viewModel.isLoadingSMS {
                    EmptyStateView(
                        icon: "message",
                        title: "Brak wiadomosci",
                        message: "Nie znaleziono SMS-ow dla wybranego filtra.",
                        actionTitle: "Odswiez"
                    ) {
                        Task { await viewModel.refreshSMS(filter: filter.rawValue) }
                    }
                } else {
                    List {
                        ForEach(filteredMessages) { message in
                            NavigationLink {
                                SMSDetailView(message: message)
                            } label: {
                                SMSRow(message: message)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteSMS(message) }
                                } label: {
                                    Label("Usun", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Szukaj w wiadomosciach")
                }
            }
            .navigationTitle("SMS")
            .refreshable { await viewModel.refreshSMS(filter: filter.rawValue) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filtr", selection: $filter) {
                            ForEach(SMSFilter.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .onChange(of: filter) { newValue in
                Task { await viewModel.refreshSMS(filter: newValue.rawValue) }
            }
            .task {
                if viewModel.messages.isEmpty {
                    await viewModel.refreshSMS(filter: filter.rawValue)
                }
            }
            .sheet(isPresented: $showingCompose) {
                ComposeSMSView()
            }
            .overlay {
                if viewModel.isLoadingSMS && viewModel.messages.isEmpty {
                    ProgressView("Pobieranie wiadomosci...")
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
}

private struct SMSRow: View {
    let message: SMSMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(message.isUnread ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.displayName.isEmpty ? "Nieznany" : message.displayName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    Text(message.timestamp)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(message.storageLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.18), in: Capsule())
                    if message.isSent {
                        Text("Wyslana")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.18), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct SMSDetailView: View {
    let message: SMSMessage
    @EnvironmentObject private var viewModel: ModemViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingReply = false

    var body: some View {
        List {
            Section("Wiadomosc") {
                Text(message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }

            Section("Szczegoly") {
                InfoRow(label: "Nadawca", value: message.sender, icon: "person")
                if !message.senderName.isEmpty {
                    InfoRow(label: "Nazwa", value: message.senderName, icon: "person.text.rectangle")
                }
                InfoRow(label: "Data", value: message.timestamp, icon: "clock")
                InfoRow(label: "Status", value: message.status, icon: "info.circle")
                InfoRow(label: "Pamiec", value: message.storageLabel, icon: "internaldrive")
                InfoRow(label: "Indeks", value: String(message.index), icon: "number")
            }

            Section {
                Button {
                    showingReply = true
                } label: {
                    Label("Odpowiedz", systemImage: "arrowshape.turn.up.left")
                }

                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteSMS(message)
                        dismiss()
                    }
                } label: {
                    Label("Usun wiadomosc", systemImage: "trash")
                }
            }
        }
        .navigationTitle(message.displayName.isEmpty ? "Wiadomosc" : message.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReply) {
            ComposeSMSView(prefilledNumber: message.sender)
        }
    }
}
