import Foundation
import Testing
@testable import CarPal

@MainActor
struct OBDArchitectureTests {
    @Test
    func adapterSessionManagerPublishesTransportState() async throws {
        let adapter = ScriptedMockAdapter(scenario: .healthy, delay: .zero)
        let manager = AdapterSessionManager(client: adapter, initializer: adapter)

        #expect(manager.connectionState == .notChecked)

        let discovered = try await manager.prepareConnection()

        #expect(discovered.name == "Veepeak OBDCheck BLE")
        #expect(manager.connectionState == .vehicleReady(name: "Veepeak OBDCheck BLE"))

        manager.disconnect()
        #expect(manager.connectionState == .disconnected)
    }

    @Test
    func commandSchedulerPreventsConcurrentELMCommands() async throws {
        let executor = RecordingELMExecutor(delay: .milliseconds(20))
        let scheduler = OBDCommandScheduler(executor: executor)

        async let first = scheduler.execute(ELMCommandRequest("010C"))
        async let second = scheduler.execute(ELMCommandRequest("010D"))
        _ = try await (first, second)

        #expect(executor.maximumConcurrentCommands == 1)
        #expect(Set(executor.commands) == ["010C", "010D"])
    }

    @Test
    func diagnosticServiceInitializesELMInsideOneOrderedOperation() async throws {
        let executor = RecordingELMExecutor(responses: ["ATI": "ELM327 v1.5"])
        let service = StandardOBDDiagnosticService(
            scheduler: OBDCommandScheduler(executor: executor)
        )

        try await service.initializeSession()

        #expect(executor.commands == [
            "ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0", "ATI"
        ])
    }

    @Test
    func diagnosticServiceReadsMode09VehicleIdentity() async throws {
        let executor = RecordingELMExecutor(responses: [
            "ATDP": "AUTO, ISO 15765-4 (CAN 11/500)",
            "0100": "41 00 18 18 00 01",
            "0900": "49 00 50 40 00 00",
            "0902": "0: 49 02 01 4A 54 4A 59 41 52\n1: 42 5A 30 4C 32 30 30 30\n2: 30 31",
            "0904": "49 04 01 43 41 4C 2D 54 45 53 54",
            "090A": "49 0A 01 45 43 4D"
        ])
        let service = StandardOBDDiagnosticService(
            scheduler: OBDCommandScheduler(executor: executor)
        )

        let identity = try await service.readVehicleIdentity()

        #expect(identity.vin == "JTJYARBZ0L2000001")
        #expect(identity.calibrationIDs == ["CAL-TEST"])
        #expect(identity.ecuNames == ["ECM"])
        #expect(identity.supportedModes == [1, 9])
        #expect(identity.protocolDescription == "AUTO, ISO 15765-4 (CAN 11/500)")
    }

    @Test
    func standardDiagnosticServiceOwnsSupportAndCoreDataComposition() async throws {
        let executor = RecordingELMExecutor(responses: [
            "0100": "41 00 3E 18 80 01",
            "0120": "41 20 00 00 00 01",
            "0140": "41 40 40 00 00 00",
            "010C": "41 0C 0B B8",
            "010D": "41 0D 00",
            "0105": "41 05 82",
            "0104": "41 04 38",
            "0111": "41 11 29",
            "0106": "41 06 84",
            "0107": "41 07 8A",
            "0142": "41 42 37 78",
            "03": "43 01 71 00 00",
            "0103": "41 03 02",
            "0202": "42 02 00"
        ])
        let service = StandardOBDDiagnosticService(
            scheduler: OBDCommandScheduler(executor: executor)
        )

        let support = try await service.discoverSupport()
        let data = try await service.retrieveCoreData()

        #expect(support.unavailableRequiredReadings.isEmpty)
        #expect(support.unavailableOptionalReadings.isEmpty)
        #expect(data.values[.engineRPM] == 750)
        #expect(data.values[.coolantTemperature] == 90)
        #expect(data.values[.controlModuleVoltage] == 14.2)
        #expect(data.troubleCodes.map(\.code) == ["P0171"])
        #expect(data.fuelSystemStatus == "Closed loop")
        #expect(data.freezeFrameAvailable)
    }
}

@MainActor
private final class RecordingELMExecutor: ELMCommandExecuting, @unchecked Sendable {
    private let responses: [String: String]
    private let delay: Duration
    private var activeCommands = 0

    private(set) var commands: [String] = []
    private(set) var maximumConcurrentCommands = 0

    init(
        responses: [String: String] = [:],
        delay: Duration = .zero
    ) {
        self.responses = responses
        self.delay = delay
    }

    func execute(_ request: ELMCommandRequest) async throws -> String {
        commands.append(request.command)
        activeCommands += 1
        maximumConcurrentCommands = max(maximumConcurrentCommands, activeCommands)
        defer { activeCommands -= 1 }

        try await Task.sleep(for: delay)
        return responses[request.command] ?? "OK"
    }
}
