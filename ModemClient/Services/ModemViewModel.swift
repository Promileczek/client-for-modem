import Foundation
import SwiftUI

/// Wspolny stan aplikacji dla aktywnego profilu.
@MainActor
final class ModemViewModel: ObservableObject {
    // Status
    @Published var status: ModemStatus?
    @Published var deviceInfo: DeviceInfo?
    @Published var dataStatus: DataStatus?
    @Published var isLoadingStatus = false

    // SMS
    @Published var messages: [SMSMessage] = []
    @Published var isLoadingSMS = false

    // Polaczenia
    @Published var callStatus: CallStatus = .idle

    // Komunikaty
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    /// Czy ostatnie odpytanie statusu sie powiodlo - steruje kropka online/offline.
    @Published var isReachable = false

    private var profile: ModemProfile?
    private var callPollTask: Task<Void, Never>?

    func setProfile(_ profile: ModemProfile?) {
        // Zmiana profilu czysci stan, zeby nie pokazywac danych z poprzedniego modemu.
        if self.profile?.id != profile?.id {
            status = nil
            deviceInfo = nil
            dataStatus = nil
            messages = []
            callStatus = .idle
            isReachable = false
            errorMessage = nil
            infoMessage = nil
        }
        self.profile = profile
    }

    private func requireProfile() -> ModemProfile? {
        guard let profile else {
            errorMessage = "Nie wybrano profilu modemu."
            return nil
        }
        return profile
    }

    private func report(_ error: Error) {
        isReachable = false
        if let apiError = error as? APIError {
            errorMessage = apiError.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Status

    func refreshStatus() async {
        guard let profile = requireProfile() else { return }
        isLoadingStatus = true
        defer { isLoadingStatus = false }
        do {
            let result = try await ModemAPI.shared.fetchStatus(profile: profile)
            status = result
            dataStatus = result.data
            isReachable = true
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    func refreshDeviceInfo() async {
        guard let profile = requireProfile() else { return }
        do {
            deviceInfo = try await ModemAPI.shared.fetchDeviceInfo(profile: profile)
            isReachable = true
        } catch {
            report(error)
        }
    }

    func refreshAll() async {
        await refreshStatus()
        await refreshDeviceInfo()
    }

    // MARK: - Transmisja danych

    func setData(enabled: Bool, apn: String? = nil) async {
        guard let profile = requireProfile() else { return }
        do {
            let response: DataControlResponse = enabled
                ? try await ModemAPI.shared.enableData(profile: profile, apn: apn)
                : try await ModemAPI.shared.disableData(profile: profile)
            infoMessage = response.message.isEmpty
                ? (enabled ? "Transmisja danych wlaczona." : "Transmisja danych wylaczona.")
                : response.message
            await refreshStatus()
        } catch {
            report(error)
        }
    }

    // MARK: - SMS

    func refreshSMS(filter: String = "ALL") async {
        guard let profile = requireProfile() else { return }
        isLoadingSMS = true
        defer { isLoadingSMS = false }
        do {
            let result = try await ModemAPI.shared.fetchSMS(profile: profile, status: filter)
            // Najnowsze na gorze - modem zwraca rosnaco po indeksie.
            messages = result.messages.sorted { $0.index > $1.index }
            isReachable = true
            errorMessage = nil
        } catch {
            report(error)
        }
    }

    func sendSMS(number: String, text: String) async -> Bool {
        guard let profile = requireProfile() else { return false }
        do {
            _ = try await ModemAPI.shared.sendSMS(profile: profile, number: number, text: text)
            infoMessage = "SMS wyslany do \(number)."
            await refreshSMS()
            return true
        } catch {
            report(error)
            return false
        }
    }

    func deleteSMS(_ message: SMSMessage) async {
        guard let profile = requireProfile() else { return }
        // Optymistyczne usuniecie z listy, przywracane przy bledzie.
        let backup = messages
        messages.removeAll { $0.id == message.id }
        do {
            try await ModemAPI.shared.deleteSMS(
                profile: profile,
                index: message.index,
                storage: message.storage.isEmpty ? nil : message.storage
            )
        } catch {
            messages = backup
            report(error)
        }
    }

    // MARK: - USSD

    func sendUSSD(code: String) async -> USSDResponse? {
        guard let profile = requireProfile() else { return nil }
        do {
            let result = try await ModemAPI.shared.sendUSSD(profile: profile, code: code)
            isReachable = true
            if !result.ok && !result.error.isEmpty {
                errorMessage = result.error
            }
            return result
        } catch {
            report(error)
            return nil
        }
    }

    func fetchSaldo() async -> SaldoResponse? {
        guard let profile = requireProfile() else { return nil }
        do {
            let result = try await ModemAPI.shared.fetchSaldo(profile: profile)
            isReachable = true
            if !result.ok && !result.error.isEmpty {
                errorMessage = result.error
            }
            return result
        } catch {
            report(error)
            return nil
        }
    }

    // MARK: - Polaczenia

    func refreshCallStatus() async {
        guard let profile = requireProfile() else { return }
        do {
            callStatus = try await ModemAPI.shared.fetchCallStatus(profile: profile)
            isReachable = true
        } catch {
            report(error)
        }
    }

    func startCall(number: String, hideNumber: Bool) async {
        guard let profile = requireProfile() else { return }
        do {
            let response = try await ModemAPI.shared.startCall(
                profile: profile, number: number, hideNumber: hideNumber
            )
            if !response.error.isEmpty {
                errorMessage = response.error
                return
            }
            callStatus = CallStatus(state: "dialing", callID: response.callID, number: number)
            startCallPolling()
        } catch {
            report(error)
        }
    }

    func answerCall() async {
        guard let profile = requireProfile() else { return }
        do {
            _ = try await ModemAPI.shared.answerCall(profile: profile)
            await refreshCallStatus()
            startCallPolling()
        } catch {
            report(error)
        }
    }

    func endCall() async {
        guard let profile = requireProfile() else { return }
        stopCallPolling()
        do {
            try await ModemAPI.shared.endCall(profile: profile)
            callStatus = .idle
        } catch {
            report(error)
        }
    }

    /// Odpytuje stan polaczenia co sekunde, dopoki trwa.
    func startCallPolling() {
        stopCallPolling()
        callPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                await self.refreshCallStatus()
                // Cala klasa jest @MainActor, wiec odczyt stanu jest tu bezpieczny.
                if self.callStatus.isIdle { return }
            }
        }
    }

    func stopCallPolling() {
        callPollTask?.cancel()
        callPollTask = nil
    }
}
