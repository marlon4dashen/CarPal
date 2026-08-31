import Foundation

struct APIRawTroubleCodeResponses: Codable, Equatable, Sendable {
    let confirmed: String
    let pending: String
    let permanent: String
}

struct APITroubleCodeParseRequest: Codable, Equatable, Sendable {
    let schemaVersion: String
    let responses: APIRawTroubleCodeResponses

    init(responses: APIRawTroubleCodeResponses, schemaVersion: String = "1") {
        self.schemaVersion = schemaVersion
        self.responses = responses
    }
}

struct APIParsedDiagnosticCode: Codable, Equatable, Sendable {
    let code: String
    let summary: String
    let state: DiagnosticCodeState
}

struct APITroubleCodeParseResponse: Codable, Equatable, Sendable {
    let schemaVersion: String
    let catalogVersion: String
    let codes: [APIParsedDiagnosticCode]

    nonisolated var report: TroubleCodeReport {
        TroubleCodeReport(
            confirmed: domainCodes(for: .confirmed),
            pending: domainCodes(for: .pending),
            permanent: domainCodes(for: .permanent)
        )
    }

    private nonisolated func domainCodes(
        for requestedState: DiagnosticCodeState
    ) -> [DiagnosticTroubleCode] {
        codes.compactMap { item in
            let matches = switch (item.state, requestedState) {
            case (.confirmed, .confirmed), (.pending, .pending), (.permanent, .permanent): true
            default: false
            }
            guard matches else { return nil }
            return DiagnosticTroubleCode(code: item.code, summary: item.summary)
        }
    }
}

struct APIReadinessParseRequest: Codable, Equatable, Sendable {
    let schemaVersion: String
    let response: String

    init(response: String, schemaVersion: String = "1") {
        self.schemaVersion = schemaVersion
        self.response = response
    }
}

enum APIReadinessIgnitionType: String, Codable, Equatable, Sendable {
    case spark
    case compression
}

struct APIReadinessMonitor: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let isComplete: Bool
}

struct APIReadinessParseResponse: Codable, Equatable, Sendable {
    let schemaVersion: String
    let isMILOn: Bool
    let confirmedDTCCount: Int
    let ignitionType: APIReadinessIgnitionType
    let monitors: [APIReadinessMonitor]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case isMILOn = "isMilOn"
        case confirmedDTCCount = "confirmedDtcCount"
        case ignitionType
        case monitors
    }

    nonisolated var report: ReadinessReport {
        let domainIgnitionType: ReadinessIgnitionType = switch ignitionType {
        case .spark: .spark
        case .compression: .compression
        }
        return ReadinessReport(
            isMILOn: isMILOn,
            confirmedDTCCount: confirmedDTCCount,
            ignitionType: domainIgnitionType,
            monitors: monitors.map {
                ReadinessMonitor(id: $0.id, name: $0.name, isComplete: $0.isComplete)
            }
        )
    }
}
