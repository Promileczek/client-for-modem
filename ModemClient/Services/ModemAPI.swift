import Foundation

enum APIError: LocalizedError {
    case invalidProfile
    case invalidURL
    case httpError(Int, String)
    case decodingFailed(String)
    case transport(String)
    case apiRejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidProfile:
            return "Profil nie ma poprawnego adresu. Sprawdz host i port."
        case .invalidURL:
            return "Nie udalo sie zbudowac adresu zapytania."
        case .httpError(let code, let body):
            if body.isEmpty {
                return "Serwer odpowiedzial bledem HTTP \(code)."
            }
            return "Blad HTTP \(code): \(body)"
        case .decodingFailed(let detail):
            return "Nie udalo sie odczytac odpowiedzi serwera. \(detail)"
        case .transport(let detail):
            return detail
        case .apiRejected(let detail):
            return detail
        }
    }
}

/// Klient REST API modemu Huawei E160G.
/// Kazde wywolanie dostaje profil, wiec ten sam klient obsluguje wiele modemow.
actor ModemAPI {
    static let shared = ModemAPI()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        // Modem odpowiada przez port szeregowy - komendy AT potrafia trwac.
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Rdzen zapytan

    private func buildRequest(
        profile: ModemProfile,
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) throws -> URLRequest {
        guard let base = profile.baseURL else { throw APIError.invalidProfile }
        guard var components = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }

        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let key = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        return request
    }

    /// Sciezki takie jak /call-+48123456789-0 zawieraja znaki wymagajace
    /// zakodowania, ale NIE chcemy kodowac samego separatora sciezki.
    private func escapePathSegment(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type
    ) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.transport(Self.describe(error))
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, Self.trimForDisplay(text))
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let preview = String(data: data, encoding: .utf8).map(Self.trimForDisplay) ?? ""
            throw APIError.decodingFailed(preview)
        }
    }

    /// Wywolanie bez potrzeby dekodowania tresci (np. rozlaczenie).
    @discardableResult
    private func performRaw(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.transport(Self.describe(error))
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, Self.trimForDisplay(text))
        }
        return data
    }

    private static func trimForDisplay(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.count > 300 ? String(clean.prefix(300)) + "..." : clean
    }

    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .cannotConnectToHost:
            return "Nie mozna polaczyc sie z modemem. Sprawdz czy serwer API dziala i czy jestes w tej samej sieci."
        case .timedOut:
            return "Przekroczono czas oczekiwania. Modem moze byc zajety inna komenda."
        case .cannotFindHost:
            return "Nie znaleziono hosta. Sprawdz adres IP w profilu."
        case .notConnectedToInternet:
            return "Brak polaczenia sieciowego na telefonie."
        case .networkConnectionLost:
            return "Polaczenie zostalo przerwane."
        case .appTransportSecurityRequiresSecureConnection:
            return "iOS zablokowal polaczenie HTTP. Sprawdz ustawienia ATS w aplikacji."
        default:
            return error.localizedDescription
        }
    }

    // MARK: - Status

    func fetchStatus(profile: ModemProfile) async throws -> ModemStatus {
        let request = try buildRequest(profile: profile, path: "status")
        return try await perform(request, as: ModemStatus.self)
    }

    func fetchSignal(profile: ModemProfile) async throws -> SignalInfo {
        let request = try buildRequest(profile: profile, path: "signal")
        return try await perform(request, as: SignalInfo.self)
    }

    func fetchDeviceInfo(profile: ModemProfile) async throws -> DeviceInfo {
        let request = try buildRequest(profile: profile, path: "device-info")
        return try await perform(request, as: DeviceInfo.self)
    }

    /// Lekki test uzywany przy zapisie profilu.
    func testConnection(profile: ModemProfile) async throws -> ModemStatus {
        try await fetchStatus(profile: profile)
    }

    // MARK: - Transmisja danych

    func fetchDataStatus(profile: ModemProfile) async throws -> DataStatus {
        let request = try buildRequest(profile: profile, path: "data-status")
        return try await perform(request, as: DataStatus.self)
    }

    func disableData(profile: ModemProfile) async throws -> DataControlResponse {
        let request = try buildRequest(profile: profile, path: "data-disable", method: "POST")
        return try await perform(request, as: DataControlResponse.self)
    }

    func enableData(profile: ModemProfile, apn: String? = nil) async throws -> DataControlResponse {
        var query: [URLQueryItem] = []
        if let apn, !apn.isEmpty {
            query.append(URLQueryItem(name: "apn", value: apn))
        }
        let request = try buildRequest(
            profile: profile, path: "data-enable", method: "POST", query: query
        )
        return try await perform(request, as: DataControlResponse.self)
    }

    // MARK: - SMS

    func fetchSMS(profile: ModemProfile, status: String = "ALL") async throws -> SMSListResponse {
        let request = try buildRequest(
            profile: profile,
            path: "sms-list",
            query: [URLQueryItem(name: "status", value: status)]
        )
        return try await perform(request, as: SMSListResponse.self)
    }

    func sendSMS(profile: ModemProfile, number: String, text: String) async throws -> SMSSendResponse {
        let payload = SMSSendRequest(number: number, text: text)
        let body = try JSONEncoder().encode(payload)
        let request = try buildRequest(
            profile: profile, path: "sms-send", method: "POST", body: body
        )
        let result = try await perform(request, as: SMSSendResponse.self)
        if !result.ok {
            let detail = result.error.isEmpty ? result.message : result.error
            throw APIError.apiRejected(detail.isEmpty ? "Modem odrzucil wyslanie SMS." : detail)
        }
        return result
    }

    func deleteSMS(profile: ModemProfile, index: Int, storage: String?) async throws {
        var query: [URLQueryItem] = []
        if let storage, !storage.isEmpty {
            query.append(URLQueryItem(name: "storage", value: storage))
        }
        let request = try buildRequest(
            profile: profile,
            path: "sms-delete/\(index)",
            method: "DELETE",
            query: query
        )
        try await performRaw(request)
    }

    // MARK: - USSD

    func fetchSaldo(profile: ModemProfile) async throws -> SaldoResponse {
        let request = try buildRequest(profile: profile, path: "saldo")
        return try await perform(request, as: SaldoResponse.self)
    }

    func sendUSSD(
        profile: ModemProfile,
        code: String,
        encoding: String? = nil
    ) async throws -> USSDResponse {
        let payload = USSDRequest(code: code, encoding: encoding)
        let body = try JSONEncoder().encode(payload)
        let request = try buildRequest(
            profile: profile, path: "ussd", method: "POST", body: body
        )
        return try await perform(request, as: USSDResponse.self)
    }

    func fetchSimOperator(profile: ModemProfile, refresh: Bool = false) async throws -> SimOperatorInfo {
        var query: [URLQueryItem] = []
        if refresh { query.append(URLQueryItem(name: "refresh", value: "true")) }
        let request = try buildRequest(profile: profile, path: "sim-operator", query: query)
        return try await perform(request, as: SimOperatorInfo.self)
    }

    // MARK: - Polaczenia

    func fetchCallStatus(profile: ModemProfile) async throws -> CallStatus {
        let request = try buildRequest(profile: profile, path: "call-status")
        return try await perform(request, as: CallStatus.self)
    }

    /// Rozpoczyna polaczenie. `private` ukrywa numer (CLIR).
    func startCall(
        profile: ModemProfile,
        number: String,
        hideNumber: Bool
    ) async throws -> CallStartResponse {
        let escaped = escapePathSegment(number)
        let path = "call-\(escaped)-\(hideNumber ? 1 : 0)"
        let request = try buildRequest(profile: profile, path: path)
        return try await perform(request, as: CallStartResponse.self)
    }

    func answerCall(profile: ModemProfile) async throws -> CallStartResponse {
        let request = try buildRequest(profile: profile, path: "call-answer")
        return try await perform(request, as: CallStartResponse.self)
    }

    func endCall(profile: ModemProfile) async throws {
        let request = try buildRequest(profile: profile, path: "call-end")
        try await performRaw(request)
    }
}
