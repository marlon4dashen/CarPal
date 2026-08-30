import Foundation
import Observation

struct DiscoveredAdapter: Equatable, Sendable {
    let id: UUID
    let name: String
}

struct OBDSupportReport: Equatable, Sendable {
    let unavailableRequiredReadings: [String]
    let unavailableOptionalReadings: [String]

    nonisolated init(
        unavailableRequiredReadings: [String] = [],
        unavailableOptionalReadings: [String]
    ) {
        self.unavailableRequiredReadings = unavailableRequiredReadings
        self.unavailableOptionalReadings = unavailableOptionalReadings
    }
}

struct ELMCommandRequest: Equatable, Sendable {
    let command: String
    let timeout: Duration
    let acceptsAnyResponse: Bool
    let allowsNoData: Bool

    nonisolated init(
        _ command: String,
        timeout: Duration = .seconds(4),
        acceptsAnyResponse: Bool = false,
        allowsNoData: Bool = false
    ) {
        self.command = command
        self.timeout = timeout
        self.acceptsAnyResponse = acceptsAnyResponse
        self.allowsNoData = allowsNoData
    }
}

@MainActor
protocol BluetoothAdapterClient: Sendable {
    var connectionState: AdapterConnectionState { get }

    func setConnectionStateHandler(
        _ handler: (@MainActor @Sendable (AdapterConnectionState) -> Void)?
    )
    func discoverSupportedAdapter() async throws -> DiscoveredAdapter
    func connect(to adapter: DiscoveredAdapter) async throws
    func disconnect()
}

@MainActor
protocol ELMCommandExecuting: Sendable {
    func execute(_ request: ELMCommandRequest) async throws -> String
}

protocol ScanDiagnosticCapabilities: Sendable {
    func initializeSession() async throws
    func discoverSupport() async throws -> OBDSupportReport
    func retrieveCoreData() async throws -> RawScanData
}

protocol OBDSessionInitializing: Sendable {
    func initializeSession() async throws
}

struct OBDVehicleIdentity: Equatable, Sendable {
    let vin: String?
    let calibrationIDs: [String]
    let ecuNames: [String]
    let supportedModes: [Int]
    let protocolDescription: String?
}

protocol VehicleIdentityReading: Sendable {
    func readVehicleIdentity() async throws -> OBDVehicleIdentity
}

struct OBDCommandSession: Sendable {
    private let executeRequest: @Sendable (ELMCommandRequest) async throws -> String

    nonisolated init(executor: any ELMCommandExecuting) {
        executeRequest = { request in
            try await executor.execute(request)
        }
    }

    nonisolated func execute(_ request: ELMCommandRequest) async throws -> String {
        try await executeRequest(request)
    }
}

actor OBDCommandScheduler {
    private let session: OBDCommandSession
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(executor: any ELMCommandExecuting) {
        session = OBDCommandSession(executor: executor)
    }

    func execute(_ request: ELMCommandRequest) async throws -> String {
        try await withExclusiveAccess { session in
            try await session.execute(request)
        }
    }

    func withExclusiveAccess<Result: Sendable>(
        _ operation: @Sendable (OBDCommandSession) async throws -> Result
    ) async throws -> Result {
        await acquire()
        defer { release() }
        return try await operation(session)
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}

@MainActor
@Observable
final class AdapterSessionManager {
    private let client: any BluetoothAdapterClient
    private let initializer: any OBDSessionInitializing
    private(set) var connectionState: AdapterConnectionState

    init(
        client: any BluetoothAdapterClient,
        initializer: any OBDSessionInitializing
    ) {
        self.client = client
        self.initializer = initializer
        connectionState = client.connectionState
        client.setConnectionStateHandler { [weak self] state in
            guard let self else { return }
            if case .vehicleReady = self.connectionState,
               case .connected = state {
                return
            }
            self.connectionState = state
        }
    }

    func discoverSupportedAdapter() async throws -> DiscoveredAdapter {
        try await client.discoverSupportedAdapter()
    }

    func connect(to adapter: DiscoveredAdapter) async throws {
        try await client.connect(to: adapter)
    }

    @discardableResult
    func prepareConnection() async throws -> DiscoveredAdapter {
        let adapter = try await discoverSupportedAdapter()
        try await connect(to: adapter)
        try await initializer.initializeSession()
        markVehicleReady(adapterName: adapter.name)
        return adapter
    }

    func markVehicleReady(adapterName: String) {
        connectionState = .vehicleReady(name: adapterName)
    }

    func disconnect() {
        client.disconnect()
    }
}

enum MockScanScenario: String, CaseIterable, Sendable {
    case serviceSoon
    case healthy
    case incompleteData
    case connectionFailure
}

@MainActor
final class ScriptedMockAdapter: BluetoothAdapterClient, ScanDiagnosticCapabilities,
    OBDSessionInitializing, VehicleIdentityReading, @unchecked Sendable {
    private enum MockError: Error {
        case connectionInterrupted
    }

    private let scenario: MockScanScenario
    private let delay: Duration
    private var stateHandler: (@MainActor @Sendable (AdapterConnectionState) -> Void)?
    private(set) var connectionState: AdapterConnectionState = .notChecked {
        didSet { stateHandler?(connectionState) }
    }

    init(scenario: MockScanScenario = .serviceSoon, delay: Duration = .milliseconds(650)) {
        self.scenario = scenario
        self.delay = delay
    }

    func setConnectionStateHandler(
        _ handler: (@MainActor @Sendable (AdapterConnectionState) -> Void)?
    ) {
        stateHandler = handler
        handler?(connectionState)
    }

    func discoverSupportedAdapter() async throws -> DiscoveredAdapter {
        connectionState = .searching
        try await pause()
        return DiscoveredAdapter(id: UUID(), name: "Veepeak OBDCheck BLE")
    }

    func connect(to adapter: DiscoveredAdapter) async throws {
        try await pause()
        if scenario == .connectionFailure {
            connectionState = .disconnected
            throw MockError.connectionInterrupted
        }
        connectionState = .connected(name: adapter.name)
    }

    func disconnect() {
        connectionState = .disconnected
    }

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

    func readVehicleIdentity() async throws -> OBDVehicleIdentity {
        try await pause()
        return OBDVehicleIdentity(
            vin: "JTJYARBZ0L2000001",
            calibrationIDs: ["CAL-NX300-TEST"],
            ecuNames: ["ECM"],
            supportedModes: [1, 3, 7, 9],
            protocolDescription: "ISO 15765-4 CAN"
        )
    }

    private func pause() async throws {
        try await Task.sleep(for: delay)
    }
}

@MainActor
final class VehicleIntegration {
    let sessionManager: AdapterSessionManager
    let diagnostics: any ScanDiagnosticCapabilities
    let identityReader: any VehicleIdentityReading

    init(
        adapterClient: any BluetoothAdapterClient,
        diagnostics: any ScanDiagnosticCapabilities,
        initializer: any OBDSessionInitializing,
        identityReader: any VehicleIdentityReading
    ) {
        sessionManager = AdapterSessionManager(client: adapterClient, initializer: initializer)
        self.diagnostics = diagnostics
        self.identityReader = identityReader
    }

    static func live() -> VehicleIntegration {
        let client = CoreBluetoothOBDClient()
        let scheduler = OBDCommandScheduler(executor: client)
        let service = StandardOBDDiagnosticService(scheduler: scheduler)
        return VehicleIntegration(
            adapterClient: client,
            diagnostics: service,
            initializer: service,
            identityReader: service
        )
    }

    static func scripted(
        scenario: MockScanScenario = .serviceSoon,
        delay: Duration = .milliseconds(650)
    ) -> VehicleIntegration {
        let mock = ScriptedMockAdapter(scenario: scenario, delay: delay)
        return VehicleIntegration(
            adapterClient: mock,
            diagnostics: mock,
            initializer: mock,
            identityReader: mock
        )
    }
}
