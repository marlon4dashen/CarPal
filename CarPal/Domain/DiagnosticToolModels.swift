import Foundation

enum DiagnosticCapabilityError: Error, Equatable, Sendable {
    case unsupported
    case malformedResponse
}

enum DiagnosticCodeState: String, CaseIterable, Codable, Identifiable, Sendable {
    case confirmed
    case pending
    case permanent

    var id: Self { self }

    var title: String {
        switch self {
        case .confirmed: "Confirmed"
        case .pending: "Pending"
        case .permanent: "Permanent"
        }
    }
}

struct TroubleCodeReport: Equatable, Sendable {
    let confirmed: [DiagnosticTroubleCode]
    let pending: [DiagnosticTroubleCode]
    let permanent: [DiagnosticTroubleCode]

    nonisolated init(
        confirmed: [DiagnosticTroubleCode] = [],
        pending: [DiagnosticTroubleCode] = [],
        permanent: [DiagnosticTroubleCode] = []
    ) {
        self.confirmed = confirmed
        self.pending = pending
        self.permanent = permanent
    }

    var totalCount: Int { confirmed.count + pending.count + permanent.count }

    func codes(for state: DiagnosticCodeState) -> [DiagnosticTroubleCode] {
        switch state {
        case .confirmed: confirmed
        case .pending: pending
        case .permanent: permanent
        }
    }
}

enum ReadinessIgnitionType: String, Equatable, Sendable {
    case spark = "Spark ignition"
    case compression = "Compression ignition"
}

struct ReadinessMonitor: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isComplete: Bool

    nonisolated init(id: String, name: String, isComplete: Bool) {
        self.id = id
        self.name = name
        self.isComplete = isComplete
    }
}

struct ReadinessReport: Equatable, Sendable {
    let isMILOn: Bool
    let confirmedDTCCount: Int
    let ignitionType: ReadinessIgnitionType
    let monitors: [ReadinessMonitor]

    nonisolated init(
        isMILOn: Bool,
        confirmedDTCCount: Int,
        ignitionType: ReadinessIgnitionType,
        monitors: [ReadinessMonitor]
    ) {
        self.isMILOn = isMILOn
        self.confirmedDTCCount = confirmedDTCCount
        self.ignitionType = ignitionType
        self.monitors = monitors
    }

    var completedMonitorCount: Int { monitors.count(where: \.isComplete) }
    var incompleteMonitorCount: Int { monitors.count - completedMonitorCount }
}

enum DiagnosticToolFailure: Error, Equatable, Sendable {
    case adapterUnavailable
    case connectionLost
    case timedOut
    case unsupported
    case invalidVehicleResponse
    case backendUnavailable
    case cancelled
    case unknown

    var title: String {
        switch self {
        case .adapterUnavailable: "Adapter unavailable"
        case .connectionLost: "Connection lost"
        case .timedOut: "Vehicle response timed out"
        case .unsupported: "Tool unavailable"
        case .invalidVehicleResponse: "Response could not be read"
        case .backendUnavailable: "Diagnostic service unavailable"
        case .cancelled: "Reading cancelled"
        case .unknown: "Reading failed"
        }
    }

    var guidance: String {
        switch self {
        case .adapterUnavailable:
            "Connect and initialize the supported adapter, then try again."
        case .connectionLost:
            "Keep the phone near the adapter and confirm the ignition is on."
        case .timedOut:
            "Leave the adapter connected and retry the reading."
        case .unsupported:
            "This vehicle did not report the standard data required by this tool."
        case .invalidVehicleResponse:
            "The adapter returned data CarPal could not safely interpret. Retry once before checking the connection."
        case .backendUnavailable:
            "CarPal read the vehicle, but could not reach the diagnostic service. Check your network and try again."
        case .cancelled:
            "No diagnostic result was saved."
        case .unknown:
            "Check the adapter connection and try again."
        }
    }
}
