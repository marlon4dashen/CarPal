import Foundation

enum ScanStage: Int, CaseIterable, Codable, Sendable {
    case searching
    case connecting
    case initializing
    case supportCheck
    case dataRetrieval
    case assessment
    case resultPreparation

    var title: String {
        switch self {
        case .searching: "Searching for adapter"
        case .connecting: "Connecting to adapter"
        case .initializing: "Initializing adapter"
        case .supportCheck: "Checking supported vehicle data"
        case .dataRetrieval: "Retrieving vehicle data"
        case .assessment: "Assessing vehicle health"
        case .resultPreparation: "Preparing your result"
        }
    }

    var activeDetail: String {
        switch self {
        case .searching: "Looking for Veepeak OBDCheck BLE"
        case .connecting: "Establishing a stable connection"
        case .initializing: "Detecting the vehicle protocol"
        case .supportCheck: "Confirming available standard readings"
        case .dataRetrieval: "Reading engine and sensor data"
        case .assessment: "Applying validated health checks"
        case .resultPreparation: "Saving your scan securely on this device"
        }
    }
}

enum ScanStageState: Equatable, Sendable {
    case waiting
    case active
    case completed(detail: String)
    case limited(detail: String)
    case failed(ScanFailure)
}

struct ScanStageSnapshot: Identifiable, Equatable, Sendable {
    let stage: ScanStage
    var state: ScanStageState

    var id: ScanStage { stage }
}

struct ScanFailure: Error, Equatable, Sendable {
    enum Code: String, Sendable {
        case adapterNotFound = "SCAN-SEARCH-001"
        case bluetoothUnavailable = "SCAN-SEARCH-002"
        case connectionFailed = "SCAN-CONNECT-001"
        case initializationFailed = "SCAN-INIT-001"
        case unsupportedVehicleData = "SCAN-SUPPORT-001"
        case dataRetrievalFailed = "SCAN-DATA-001"
        case assessmentFailed = "SCAN-ASSESS-001"
        case resultBuildFailed = "SCAN-RESULT-001"
    }

    let stage: ScanStage
    let code: Code
    let message: String
    let guidance: String
    let allowsRetry: Bool
    let technicalContext: String?
}

enum SensorMetric: String, CaseIterable, Codable, Sendable {
    case engineRPM
    case vehicleSpeed
    case coolantTemperature
    case calculatedEngineLoad
    case throttlePosition
    case shortTermFuelTrim
    case longTermFuelTrim
    case controlModuleVoltage
}

struct DiagnosticTroubleCode: Codable, Equatable, Sendable {
    let code: String
    let summary: String

    nonisolated init(code: String, summary: String) {
        self.code = code
        self.summary = summary
    }
}

struct RawScanData: Equatable, Sendable {
    let values: [SensorMetric: Double]
    let troubleCodes: [DiagnosticTroubleCode]
    let troubleCodesAvailable: Bool
    let fuelSystemStatus: String?
    let freezeFrameAvailable: Bool

    nonisolated init(
        values: [SensorMetric: Double],
        troubleCodes: [DiagnosticTroubleCode],
        troubleCodesAvailable: Bool,
        fuelSystemStatus: String?,
        freezeFrameAvailable: Bool
    ) {
        self.values = values
        self.troubleCodes = troubleCodes
        self.troubleCodesAvailable = troubleCodesAvailable
        self.fuelSystemStatus = fuelSystemStatus
        self.freezeFrameAvailable = freezeFrameAvailable
    }
}

struct NormalizedScan: Equatable, Sendable {
    let values: [SensorMetric: Double]
    let troubleCodes: [DiagnosticTroubleCode]
    let troubleCodesAvailable: Bool
    let fuelSystemStatus: String?
    let freezeFrameAvailable: Bool

    var completeness: Double {
        let availableReadings = SensorMetric.allCases.filter { values[$0] != nil }.count
        let availableGroups = availableReadings
            + (troubleCodesAvailable ? 1 : 0)
            + (fuelSystemStatus == nil ? 0 : 1)
        return Double(availableGroups) / Double(SensorMetric.allCases.count + 2)
    }
}

enum FindingSeverity: String, Codable, Equatable, Sendable {
    case information
    case attention
    case urgent
}

struct AssessmentFinding: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let whyItMatters: String
    let severity: FindingSeverity
    let technicalDetail: String

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        whyItMatters: String,
        severity: FindingSeverity,
        technicalDetail: String
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.whyItMatters = whyItMatters
        self.severity = severity
        self.technicalDetail = technicalDetail
    }
}

enum AssessmentAction: String, Codable, Equatable, Sendable {
    case noImmediateAction
    case continueMonitoring
    case scheduleRoutineService
    case arrangeDiagnosticInspection
    case stopDrivingWhenSafe
    case scanAgain

    var title: String {
        switch self {
        case .noImmediateAction: "No immediate action required"
        case .continueMonitoring: "Continue monitoring"
        case .scheduleRoutineService: "Schedule routine service"
        case .arrangeDiagnosticInspection: "Book a diagnostic inspection"
        case .stopDrivingWhenSafe: "Stop driving when safe"
        case .scanAgain: "Scan again"
        }
    }
}

struct ScanResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let vehicleID: UUID
    let scannedAt: Date
    let status: AssessmentStatus
    let score: Int?
    let completeness: Double
    let summary: String
    let whyItMatters: String
    let action: AssessmentAction
    let findings: [AssessmentFinding]
    let unavailableData: [String]
    let technicalSummary: String
    let blockingReason: String?

    var isAssessed: Bool { status != .unableToAssess }
}
