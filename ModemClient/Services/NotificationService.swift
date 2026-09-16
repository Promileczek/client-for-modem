import Foundation
import UIKit
import UserNotifications

/// Powiadomienia lokalne o nowych SMS-ach i polaczeniach przychodzacych.
///
/// Uzywamy powiadomien lokalnych, nie push przez APNs - te wymagaja platnego
/// konta Apple Developer i certyfikatu po stronie serwera. Lokalne dzialaja
/// od reki, ale tylko wtedy, gdy aplikacja moze sprawdzic modem: na pierwszym
/// planie albo podczas odswiezania w tle, o ktorego terminie decyduje iOS.
@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var isAuthorized = false

    /// Identyfikatory SMS-ow, o ktorych juz powiadomilismy.
    /// Bez tego kazde odswiezenie listy alarmowaloby o tych samych wiadomosciach.
    private var notifiedMessageIDs: Set<String> = []
    private var lastKnownCallID: String?

    private let notifiedKey = "modem.notifiedMessages.v1"
    private let enabledKey = "modem.notificationsEnabled.v1"

    /// Przelacznik widoczny w ustawieniach aplikacji.
    var notificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private override init() {
        super.init()
        loadNotifiedIDs()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Uprawnienia

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - Wykrywanie nowych zdarzen

    /// Porownuje swieza liste SMS z tym, o czym juz powiadomilismy,
    /// i zglasza tylko nowe wiadomosci przychodzace.
    ///
    /// - Parameter isFirstLoad: przy pierwszym pobraniu po starcie aplikacji
    ///   tylko zapamietujemy stan, zeby nie zasypac uzytkownika powiadomieniami
    ///   o wiadomosciach sprzed instalacji.
    func processNewMessages(_ messages: [SMSMessage], isFirstLoad: Bool) async {
        guard notificationsEnabled else { return }

        let incoming = messages.filter { !$0.isSent }

        if isFirstLoad {
            notifiedMessageIDs = Set(incoming.map(\.id))
            persistNotifiedIDs()
            return
        }

        let fresh = incoming.filter { !notifiedMessageIDs.contains($0.id) }
        guard !fresh.isEmpty else { return }

        // Przy wielu nowych naraz pokazujemy zbiorcze powiadomienie,
        // zeby nie zablokowac ekranu dziesiatkami alertow.
        if fresh.count > 3 {
            await postNotification(
                identifier: "sms-batch-\(Date().timeIntervalSince1970)",
                title: "Nowe wiadomosci",
                body: "Odebrano \(fresh.count) nowych SMS-ow.",
                categoryID: "SMS"
            )
        } else {
            for message in fresh {
                let sender = message.displayName.isEmpty ? "Nieznany numer" : message.displayName
                await postNotification(
                    identifier: "sms-\(message.id)",
                    title: sender,
                    body: message.text.isEmpty ? "(pusta wiadomosc)" : message.text,
                    categoryID: "SMS"
                )
            }
        }

        notifiedMessageIDs.formUnion(fresh.map(\.id))
        trimNotifiedIDs()
        persistNotifiedIDs()

        await updateBadge(count: incoming.filter(\.isUnread).count)
    }

    /// Zglasza polaczenie przychodzace. Alarmujemy raz na polaczenie,
    /// bo status jest odpytywany co sekunde.
    func processCallStatus(_ status: CallStatus) async {
        guard notificationsEnabled else { return }

        guard status.isRinging else {
            // Polaczenie sie skonczylo - kasujemy blokade, by nastepne zadzwonilo.
            if status.isIdle { lastKnownCallID = nil }
            return
        }

        let callKey = status.callID ?? status.number ?? "unknown"
        guard callKey != lastKnownCallID else { return }
        lastKnownCallID = callKey

        let number = status.number?.isEmpty == false ? status.number! : "Numer zastrzezony"
        await postNotification(
            identifier: "call-\(callKey)",
            title: "Polaczenie przychodzace",
            body: "Dzwoni: \(number)",
            categoryID: "CALL",
            sound: .defaultRingtone
        )
    }

    // MARK: - Wysylanie

    private func postNotification(
        identifier: String,
        title: String,
        body: String,
        categoryID: String,
        sound: UNNotificationSound = .default
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.categoryIdentifier = categoryID

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil          // nil = pokaz natychmiast
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func updateBadge(count: Int) async {
        let value = max(0, count)
        // setBadgeCount pojawilo sie w iOS 17, a celujemy w 16.
        if #available(iOS 17.0, *) {
            try? await UNUserNotificationCenter.current().setBadgeCount(value)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = value
        }
    }

    func clearBadge() async {
        await updateBadge(count: 0)
    }

    // MARK: - Trwalosc

    /// Zbior rosnie w nieskonczonosc, wiec przycinamy go do rozsadnego rozmiaru.
    private func trimNotifiedIDs() {
        guard notifiedMessageIDs.count > 500 else { return }
        notifiedMessageIDs = Set(notifiedMessageIDs.suffix(300))
    }

    private func loadNotifiedIDs() {
        if let saved = UserDefaults.standard.stringArray(forKey: notifiedKey) {
            notifiedMessageIDs = Set(saved)
        }
    }

    private func persistNotifiedIDs() {
        UserDefaults.standard.set(Array(notifiedMessageIDs), forKey: notifiedKey)
    }

    /// Po zmianie profilu historia powiadomien z poprzedniego modemu jest bez znaczenia.
    func resetForProfileChange() {
        notifiedMessageIDs = []
        lastKnownCallID = nil
        persistNotifiedIDs()
    }
}

// MARK: - Zachowanie na pierwszym planie

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Domyslnie iOS ukrywa powiadomienia, gdy aplikacja jest otwarta.
    /// Chcemy je widziec takze wtedy - to glowny tryb pracy tej aplikacji.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
