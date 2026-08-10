import Foundation

struct DiscoveredAdapter: Equatable, Sendable {
    let id: UUID
    let name: String
}

struct OBDSupportReport: Equatable, Sendable {
    let unavailableRequiredReadings: [String]
    let unavailableOptionalReadings: [String]

    init(
        unavailableRequiredReadings: [String] = [],
        unavailableOptionalReadings: [String]
    ) {
        self.unavailableRequiredReadings = unavailableRequiredReadings
        self.unavailableOptionalReadings = unavailableOptionalReadings
    }
}

protocol BluetoothAdapterClient: Sendable {
    func discoverSupportedAdapter() async throws -> DiscoveredAdapter
    func connect(to adapter: DiscoveredAdapter) async throws
    func disconnect()
}

protocol OBDCommandClient: Sendable {
    func initializeSession() async throws
    func discoverSupport() async throws -> OBDSupportReport
    func retrieveCoreData() async throws -> RawScanData
}

enum MockScanScenario: String, CaseIterable, Sendable {
    case serviceSoon
    case healthy
    case incompleteData
    case connectionFailure
}

@MainActor
final class ScriptedMockAdapter: BluetoothAdapterClient, OBDCommandClient, @unchecked Sendable {
    private enum MockError: Error {
        case connectionInterrupted
    }

    private let scenario: MockScanScenario
    private let delay: Duration

    init(scenario: MockScanScenario = .serviceSoon, delay: Duration = .milliseconds(650)) {
        self.scenario = scenario
        self.delay = delay
    }

    func discoverSupportedAdapter() async throws -> DiscoveredAdapter {
        try await pause()
        return DiscoveredAdapter(id: UUID(), name: "Veepeak OBDCheck BLE")
    }

    func connect(to adapter: DiscoveredAdapter) async throws {
        try await pause()
        if scenario == .connectionFailure {
            throw MockError.connectionInterrupted
        }
    }

    func disconnect() {}

    func initializeSession() async throws {
        try await pause()
    }

    func discoverSupport() async throws -> OBDSupportReport {
        try await pause()
        return OBDSupportReport(
            unavailableOptionalReadings: ["Intake airflow", "Fuel level"]
        )
    }

    func retrieveCoreData() async throws -> RawScanData {
        try await pause()

        var values: [SensorMetric: Double] = [
            .engineRPM: 742,
            .vehicleSpeed: 0,
            .coolantTemperature: 91,
            .calculatedEngineLoad: 24,
            .throttlePosition: 17,
            .shortTermFuelTrim: 3.1,
            .longTermFuelTrim: 8.4,
            .controlModuleVoltage: 14.2
        ]

        if scenario == .incompleteData {
            values.removeValue(forKey: .engineRPM)
            values.removeValue(forKey: .coolantTemperature)
            values.removeValue(forKey: .controlModuleVoltage)
        }

        let codes = scenario == .serviceSoon
            ? [DiagnosticTroubleCode(code: "P0171", summary: "System too lean")]
            : []

        return RawScanData(
            values: values,
            troubleCodes: codes,
            troubleCodesAvailable: true,
            fuelSystemStatus: scenario == .incompleteData ? nil : "Closed loop",
            freezeFrameAvailable: scenario == .serviceSoon
        )
    }

    private func pause() async throws {
        try await Task.sleep(for: delay)
    }
}
