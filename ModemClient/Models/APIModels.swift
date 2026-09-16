import Foundation

// MARK: - SMS

struct SMSMessage: Codable, Identifiable, Equatable {
    let index: Int
    let status: String
    let sender: String
    let senderName: String
    let timestamp: String
    let text: String
    let storage: String

    /// Indeksy powtarzaja sie miedzy pamieciami SM i ME, wiec samo `index`
    /// nie jest unikalne - identyfikator musi laczyc oba pola.
    var id: String { "\(storage)-\(index)" }

    enum CodingKeys: String, CodingKey {
        case index, status, sender, text, storage
        case senderName = "sender_name"
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        sender = try c.decodeIfPresent(String.self, forKey: .sender) ?? ""
        senderName = try c.decodeIfPresent(String.self, forKey: .senderName) ?? ""
        timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        storage = try c.decodeIfPresent(String.self, forKey: .storage) ?? ""
    }

    init(index: Int, status: String, sender: String, senderName: String = "",
         timestamp: String = "", text: String = "", storage: String = "") {
        self.index = index
        self.status = status
        self.sender = sender
        self.senderName = senderName
        self.timestamp = timestamp
        self.text = text
        self.storage = storage
    }

    var isUnread: Bool { status.uppercased().contains("UNREAD") }
    var isSent: Bool { status.uppercased().contains("SENT") }

    /// Nazwa nadawcy jesli modem ja rozpoznal, inaczej surowy numer.
    var displayName: String {
        senderName.isEmpty ? sender : senderName
    }

    /// Nazwa pamieci w formie czytelnej dla czlowieka.
    var storageLabel: String {
        switch storage.uppercased() {
        case "SM": return "SIM"
        case "ME": return "Modem"
        default: return storage
        }
    }
}

struct SMSListResponse: Codable {
    let ok: Bool
    let messages: [SMSMessage]
    let count: Int

    enum CodingKeys: String, CodingKey { case ok, messages, count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        messages = try c.decodeIfPresent([SMSMessage].self, forKey: .messages) ?? []
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

struct SMSSendRequest: Codable {
    let number: String
    let text: String
}

struct SMSSendResponse: Codable {
    let ok: Bool
    let message: String
    let error: String

    enum CodingKeys: String, CodingKey { case ok, message, error }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        error = try c.decodeIfPresent(String.self, forKey: .error) ?? ""
    }
}

// MARK: - Status

struct SignalInfo: Codable, Equatable {
    let ok: Bool
    let rssi: Int
    let rssiDBm: Int
    let ber: Int
    let quality: String

    enum CodingKeys: String, CodingKey {
        case ok, rssi, ber, quality
        case rssiDBm = "rssi_dbm"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        rssi = try c.decodeIfPresent(Int.self, forKey: .rssi) ?? 0
        rssiDBm = try c.decodeIfPresent(Int.self, forKey: .rssiDBm) ?? 0
        ber = try c.decodeIfPresent(Int.self, forKey: .ber) ?? 99
        quality = try c.decodeIfPresent(String.self, forKey: .quality) ?? "unknown"
    }

    /// RSSI raportowane przez AT+CSQ ma zakres 0...31 (99 = brak pomiaru).
    var bars: Int {
        guard ok, rssi <= 31 else { return 0 }
        switch rssi {
        case 0...5: return 1
        case 6...12: return 2
        case 13...19: return 3
        case 20...25: return 4
        default: return 5
        }
    }
}

struct OperatorInfo: Codable, Equatable {
    let ok: Bool
    let name: String
    let mode: String

    enum CodingKeys: String, CodingKey {
        case ok, mode
        case name = "operator"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? ""
    }
}

struct RegistrationInfo: Codable, Equatable {
    let ok: Bool
    let status: String
    let statusCode: Int
    let registered: Bool

    enum CodingKeys: String, CodingKey {
        case ok, status, registered
        case statusCode = "status_code"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        statusCode = try c.decodeIfPresent(Int.self, forKey: .statusCode) ?? -1
        registered = try c.decodeIfPresent(Bool.self, forKey: .registered) ?? false
    }
}

struct SIMInfo: Codable, Equatable {
    let ok: Bool
    let status: String
    let ready: Bool

    enum CodingKeys: String, CodingKey { case ok, status, ready }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        ready = try c.decodeIfPresent(Bool.self, forKey: .ready) ?? false
    }
}

struct DataStatus: Codable, Equatable {
    let ok: Bool
    let dataDisabled: Bool
    let gprsAttached: Bool
    let serviceDomain: String?
    let pdpContext: String

    enum CodingKeys: String, CodingKey {
        case ok
        case dataDisabled = "data_disabled"
        case gprsAttached = "gprs_attached"
        case serviceDomain = "service_domain"
        case pdpContext = "pdp_context"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        dataDisabled = try c.decodeIfPresent(Bool.self, forKey: .dataDisabled) ?? false
        gprsAttached = try c.decodeIfPresent(Bool.self, forKey: .gprsAttached) ?? false
        serviceDomain = try c.decodeIfPresent(String.self, forKey: .serviceDomain)
        pdpContext = try c.decodeIfPresent(String.self, forKey: .pdpContext) ?? ""
    }
}

struct ModemStatus: Codable, Equatable {
    let ok: Bool
    let signal: SignalInfo?
    let `operator`: OperatorInfo?
    let registration: RegistrationInfo?
    let sim: SIMInfo?
    let data: DataStatus?

    enum CodingKeys: String, CodingKey {
        case ok, signal, registration, sim, data
        case `operator`
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        signal = try c.decodeIfPresent(SignalInfo.self, forKey: .signal)
        `operator` = try c.decodeIfPresent(OperatorInfo.self, forKey: .operator)
        registration = try c.decodeIfPresent(RegistrationInfo.self, forKey: .registration)
        sim = try c.decodeIfPresent(SIMInfo.self, forKey: .sim)
        data = try c.decodeIfPresent(DataStatus.self, forKey: .data)
    }
}

struct DeviceInfo: Codable, Equatable {
    let ok: Bool
    let model: String
    let imei: String
    let imsi: String
    let firmware: String
    let simStatus: String

    enum CodingKeys: String, CodingKey {
        case ok, model, imei, imsi, firmware
        case simStatus = "sim_status"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        imei = try c.decodeIfPresent(String.self, forKey: .imei) ?? ""
        imsi = try c.decodeIfPresent(String.self, forKey: .imsi) ?? ""
        firmware = try c.decodeIfPresent(String.self, forKey: .firmware) ?? ""
        simStatus = try c.decodeIfPresent(String.self, forKey: .simStatus) ?? ""
    }

    /// Pole `model` przychodzi jako wielolinijkowy zrzut z AT+CGMI/CGMM.
    /// Wyciagamy z niego sama nazwe modelu.
    var shortModel: String {
        for line in model.split(separator: "\n") {
            if line.hasPrefix("Model:") {
                return line.dropFirst("Model:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        return model.split(separator: "\n").first.map(String.init) ?? model
    }

    var manufacturer: String {
        for line in model.split(separator: "\n") {
            if line.hasPrefix("Manufacturer:") {
                return line.dropFirst("Manufacturer:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }
}

struct DataControlResponse: Codable {
    let ok: Bool
    let message: String
    let dataDisabled: Bool

    enum CodingKeys: String, CodingKey {
        case ok, message
        case dataDisabled = "data_disabled"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        dataDisabled = try c.decodeIfPresent(Bool.self, forKey: .dataDisabled) ?? false
    }
}

// MARK: - USSD

struct USSDRequest: Codable {
    let code: String
    let dcs: Int
    let encoding: String?

    init(code: String, dcs: Int = 15, encoding: String? = nil) {
        self.code = code
        self.dcs = dcs
        self.encoding = encoding
    }
}

struct USSDResponse: Codable {
    let ok: Bool
    let response: String
    let rawResponse: String
    let usedCode: String
    let encoding: String
    let error: String

    enum CodingKeys: String, CodingKey {
        case ok, response, encoding, error
        case rawResponse = "raw_response"
        case usedCode = "used_code"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        response = try c.decodeIfPresent(String.self, forKey: .response) ?? ""
        rawResponse = try c.decodeIfPresent(String.self, forKey: .rawResponse) ?? ""
        usedCode = try c.decodeIfPresent(String.self, forKey: .usedCode) ?? ""
        encoding = try c.decodeIfPresent(String.self, forKey: .encoding) ?? ""
        error = try c.decodeIfPresent(String.self, forKey: .error) ?? ""
    }
}

struct SaldoResponse: Codable {
    let ok: Bool
    let saldo: String
    let rawResponse: String
    let `operator`: String
    let usedCode: String
    let error: String

    enum CodingKeys: String, CodingKey {
        case ok, saldo, error
        case rawResponse = "raw_response"
        case `operator`
        case usedCode = "used_code"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        saldo = try c.decodeIfPresent(String.self, forKey: .saldo) ?? ""
        rawResponse = try c.decodeIfPresent(String.self, forKey: .rawResponse) ?? ""
        `operator` = try c.decodeIfPresent(String.self, forKey: .operator) ?? ""
        usedCode = try c.decodeIfPresent(String.self, forKey: .usedCode) ?? ""
        error = try c.decodeIfPresent(String.self, forKey: .error) ?? ""
    }
}

struct SimOperatorInfo: Codable {
    let ok: Bool
    let key: String
    let name: String
    let country: String
    let imsi: String
    let mccmnc: String
    let operatorName: String
    let saldoCodes: [String]

    enum CodingKeys: String, CodingKey {
        case ok, key, name, country, imsi, mccmnc
        case operatorName = "operator_name"
        case saldoCodes = "saldo_codes"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        country = try c.decodeIfPresent(String.self, forKey: .country) ?? ""
        imsi = try c.decodeIfPresent(String.self, forKey: .imsi) ?? ""
        mccmnc = try c.decodeIfPresent(String.self, forKey: .mccmnc) ?? ""
        operatorName = try c.decodeIfPresent(String.self, forKey: .operatorName) ?? ""
        saldoCodes = try c.decodeIfPresent([String].self, forKey: .saldoCodes) ?? []
    }
}

// MARK: - Polaczenia

struct CallStatus: Codable, Equatable {
    let state: String
    let callID: String?
    let number: String?

    enum CodingKeys: String, CodingKey {
        case state, number
        case callID = "call_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? "idle"
        callID = try c.decodeIfPresent(String.self, forKey: .callID)
        number = try c.decodeIfPresent(String.self, forKey: .number)
    }

    init(state: String, callID: String? = nil, number: String? = nil) {
        self.state = state
        self.callID = callID
        self.number = number
    }

    var isIdle: Bool { state.lowercased() == "idle" }
    var isRinging: Bool { state.lowercased().contains("ring") || state.lowercased().contains("incoming") }
    var isActive: Bool { !isIdle }

    static let idle = CallStatus(state: "idle")

    /// Etykieta stanu po polsku dla ekranu polaczenia.
    var displayState: String {
        switch state.lowercased() {
        case "idle": return "Bezczynny"
        case "dialing", "calling": return "Wybieranie..."
        case "ringing": return "Dzwoni..."
        case "incoming": return "Polaczenie przychodzace"
        case "active", "connected", "in_call": return "Polaczenie w toku"
        default: return state.capitalized
        }
    }
}

/// Odpowiedz z /call-{number}-{private} - serwer zwraca call_id.
struct CallStartResponse: Codable {
    let ok: Bool
    let callID: String?
    let message: String
    let error: String

    enum CodingKeys: String, CodingKey {
        case ok, message, error
        case callID = "call_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        callID = try c.decodeIfPresent(String.self, forKey: .callID)
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        error = try c.decodeIfPresent(String.self, forKey: .error) ?? ""
    }
}
