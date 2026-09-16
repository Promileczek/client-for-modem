import Foundation

/// Zapisany profil modemu - odpowiednik konta w Zoiperze, tyle ze po REST API.
struct ModemProfile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var host: String
    var port: Int
    var useHTTPS: Bool
    /// Opcjonalny klucz API wysylany jako naglowek X-API-Key.
    /// Obecne API go nie wymaga, ale zostawiamy miejsce na zabezpieczenie.
    var apiKey: String
    /// Kolor etykiety na liscie profili (indeks w ProfileColor.all).
    var colorIndex: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 7500,
        useHTTPS: Bool = false,
        apiKey: String = "",
        colorIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.useHTTPS = useHTTPS
        self.apiKey = apiKey
        self.colorIndex = colorIndex
    }

    var scheme: String { useHTTPS ? "https" : "http" }

    /// Bazowy adres API, np. http://192.168.0.119:7500
    var baseURL: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        components.port = port
        return components.url
    }

    /// Adres WebSocket dla strumieni audio (etap 2).
    var webSocketScheme: String { useHTTPS ? "wss" : "ws" }

    /// Krotki opis pokazywany pod nazwa profilu.
    var subtitle: String {
        "\(scheme)://\(host):\(port)"
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !host.trimmingCharacters(in: .whitespaces).isEmpty
            && (1...65535).contains(port)
    }
}
