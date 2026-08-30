import Foundation
import Observation

@MainActor
@Observable
final class ScanCoordinator {
    private let sessionManager: AdapterSessionManager
    private let diagnostics: any ScanDiagnosticCapabilities
    private let normalizer: ScanNormalizer
    private let assessmentEngine: HealthAssessmentEngine

    private(set) var stages = ScanStage.allCases.map {
        ScanStageSnapshot(stage: $0, state: .waiting)
    }
    private(set) var result: ScanResult?
    private(set) var failure: ScanFailure?
    private(set) var isRunning = false
    private(set) var hasCollectedData = false

    init(
        sessionManager: AdapterSessionManager,
        diagnostics: any ScanDiagnosticCapabilities,
        normalizer: ScanNormalizer = ScanNormalizer(),
        assessmentEngine: HealthAssessmentEngine = HealthAssessmentEngine()
    ) {
        self.sessionManager = sessionManager
        self.diagnostics = diagnostics
        self.normalizer = normalizer
        self.assessmentEngine = assessmentEngine
    }

    var activeStage: ScanStage? {
        stages.first { if case .active = $0.state { true } else { false } }?.stage
    }

    var progress: Double {
        let finished = stages.filter {
            switch $0.state {
            case .completed, .limited: true
            default: false
            }
        }.count
        let activeCredit = activeStage == nil ? 0 : 0.45
        return min(1, (Double(finished) + activeCredit) / Double(stages.count))
    }

    func begin(vehicleID: UUID, at date: Date = .now) async {
        reset()
        isRunning = true

        do {
            setActive(.searching)
            let adapter = try await sessionManager.discoverSupportedAdapter()
            try ensureRunning()
            setFinished(.searching, detail: "Found \(adapter.name)")

            setActive(.connecting)
            try await sessionManager.connect(to: adapter)
            try ensureRunning()
            setFinished(.connecting, detail: "Connection is stable")

            setActive(.initializing)
            try await diagnostics.initializeSession()
            try ensureRunning()
            sessionManager.markVehicleReady(adapterName: adapter.name)
            setFinished(.initializing, detail: "Vehicle protocol detected")

            setActive(.supportCheck)
            let support = try await diagnostics.discoverSupport()
            try ensureRunning()
            if !support.unavailableRequiredReadings.isEmpty {
                setLimited(
                    .supportCheck,
                    detail: "\(support.unavailableRequiredReadings.count) required readings unavailable; the result may be unable to assess"
                )
            } else if support.unavailableOptionalReadings.isEmpty {
                setFinished(.supportCheck, detail: "Core and optional readings available")
            } else {
                setLimited(
                    .supportCheck,
                    detail: "\(support.unavailableOptionalReadings.count) optional readings unavailable; assessment can continue"
                )
            }

            setActive(.dataRetrieval)
            let raw = try await diagnostics.retrieveCoreData()
            try ensureRunning()
            hasCollectedData = true
            setFinished(.dataRetrieval, detail: "Core scan data retrieved")

            setActive(.assessment)
            let normalized = normalizer.normalize(raw)
            let assessment = assessmentEngine.assess(
                scan: normalized,
                vehicleID: vehicleID,
                at: date
            )
            setFinished(
                .assessment,
                detail: assessment.isAssessed ? "Assessment completed" : "Assessment limits identified"
            )

            setActive(.resultPreparation)
            try await Task.sleep(for: .milliseconds(220))
            try ensureRunning()
            result = assessment
            setFinished(.resultPreparation, detail: "Result ready")
            isRunning = false
        } catch is CancellationError {
            isRunning = false
        } catch {
            let stage = activeStage ?? .searching
            let failure = Self.failure(for: stage, underlying: error)
            self.failure = failure
            setFailed(stage, failure: failure)
            isRunning = false
        }
    }

    func cancel() {
        isRunning = false
        sessionManager.disconnect()
    }

    private func reset() {
        stages = ScanStage.allCases.map { ScanStageSnapshot(stage: $0, state: .waiting) }
        result = nil
        failure = nil
        hasCollectedData = false
    }

    private func ensureRunning() throws {
        guard isRunning else { throw CancellationError() }
    }

    private func update(_ stage: ScanStage, state: ScanStageState) {
        guard let index = stages.firstIndex(where: { $0.stage == stage }) else { return }
        stages[index].state = state
    }

    private func setActive(_ stage: ScanStage) { update(stage, state: .active) }
    private func setFinished(_ stage: ScanStage, detail: String) {
        update(stage, state: .completed(detail: detail))
    }
    private func setLimited(_ stage: ScanStage, detail: String) {
        update(stage, state: .limited(detail: detail))
    }
    private func setFailed(_ stage: ScanStage, failure: ScanFailure) {
        update(stage, state: .failed(failure))
    }

    private static func failure(for stage: ScanStage, underlying: Error) -> ScanFailure {
        let context = String(describing: underlying)
        if case OBDTransportError.bluetoothUnavailable = underlying {
            return ScanFailure(
                stage: .searching,
                code: .bluetoothUnavailable,
                message: "Bluetooth is not available for this scan.",
                guidance: "Turn on Bluetooth and allow CarPal Bluetooth access, then try again.",
                allowsRetry: true,
                technicalContext: context
            )
        }
        return switch stage {
        case .searching:
            ScanFailure(
                stage: stage,
                code: .adapterNotFound,
                message: "CarPal could not find the supported adapter.",
                guidance: "Confirm the adapter is plugged in and stay near the vehicle.",
                allowsRetry: true,
                technicalContext: context
            )
        case .connecting:
            ScanFailure(
                stage: stage,
                code: .connectionFailed,
                message: "The adapter connection was interrupted.",
                guidance: "Keep your phone near the adapter and confirm Bluetooth is on.",
                allowsRetry: true,
                technicalContext: context
            )
        case .initializing:
            ScanFailure(
                stage: stage,
                code: .initializationFailed,
                message: "The adapter did not initialize correctly.",
                guidance: "Leave the adapter plugged in, then try the scan again.",
                allowsRetry: true,
                technicalContext: context
            )
        case .supportCheck:
            ScanFailure(
                stage: stage,
                code: .unsupportedVehicleData,
                message: "Required standard vehicle data is unavailable.",
                guidance: "Confirm the ignition is on and the engine is running.",
                allowsRetry: true,
                technicalContext: context
            )
        case .dataRetrieval:
            ScanFailure(
                stage: stage,
                code: .dataRetrievalFailed,
                message: "CarPal could not finish reading vehicle data.",
                guidance: "Do not unplug the adapter. Keep the engine running and try again.",
                allowsRetry: true,
                technicalContext: context
            )
        case .assessment:
            ScanFailure(
                stage: stage,
                code: .assessmentFailed,
                message: "The retrieved data could not be assessed.",
                guidance: "Start a new scan. No health score was saved.",
                allowsRetry: true,
                technicalContext: context
            )
        case .resultPreparation:
            ScanFailure(
                stage: stage,
                code: .resultBuildFailed,
                message: "CarPal could not prepare the scan result.",
                guidance: "Try the scan again. Your vehicle profile is unchanged.",
                allowsRetry: true,
                technicalContext: context
            )
        }
    }
}
