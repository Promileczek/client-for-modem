import BackgroundTasks
import Foundation

/// Odswiezanie w tle: sprawdza nowe SMS-y, gdy aplikacja nie jest na ekranie.
///
/// iOS sam decyduje, kiedy uruchomic takie zadanie - bierze pod uwage poziom
/// baterii, tryb niskiego zuzycia energii i to, jak czesto korzystasz z aplikacji.
/// Moze to byc co kilkanascie minut, ale przy rzadko uzywanej aplikacji rownie
/// dobrze raz na kilka godzin. Gwarantowanych powiadomien daje tylko APNs.
enum BackgroundRefreshService {
    /// Musi byc zgodne z wpisem BGTaskSchedulerPermittedIdentifiers w Info.plist.
    static let taskIdentifier = "com.modemclient.app.refresh"

    /// Rejestracja musi nastapic przed koncem uruchamiania aplikacji.
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleRefresh(task: refreshTask)
        }
    }

    /// Planuje kolejne sprawdzenie. Wywolujemy przy przejsciu w tlo
    /// oraz po kazdym wykonanym zadaniu - iOS pozwala miec jedno w kolejce.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // Proba nie wczesniej niz za 15 minut; system i tak moze zwlekac dluzej.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Najczestsza przyczyna: uzytkownik wylaczyl odswiezanie w tle
            // albo dziala tryb niskiego zuzycia energii. Nie jest to blad krytyczny.
            print("Nie udalo sie zaplanowac odswiezania w tle: \(error)")
        }
    }

    private static func handleRefresh(task: BGAppRefreshTask) {
        // Kolejne zadanie planujemy od razu, inaczej lancuch sie urwie.
        schedule()

        let work = Task {
            let success = await checkForNewMessages()
            task.setTaskCompleted(success: success)
        }

        // iOS daje krotkie okno; po jego przekroczeniu zadanie jest ubijane.
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    /// Pobiera SMS-y aktywnego profilu i zglasza nowe do powiadomien.
    private static func checkForNewMessages() async -> Bool {
        let profile = await MainActor.run { ProfileStore.sharedSelectedProfile() }
        guard let profile else { return false }

        do {
            let response = try await ModemAPI.shared.fetchSMS(profile: profile, status: "ALL")
            await NotificationService.shared.processNewMessages(
                response.messages,
                isFirstLoad: false
            )
            return true
        } catch {
            // Modem poza zasiegiem to normalna sytuacja w tle - nie alarmujemy.
            return false
        }
    }
}
