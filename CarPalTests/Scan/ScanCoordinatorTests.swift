import Foundation
import Testing
@testable import CarPal

@MainActor
struct ScanCoordinatorTests {
    @Test
    func scriptedScanCompletesAllSevenStagesInOrder() async {
        let mock = ScriptedMockAdapter(scenario: .serviceSoon, delay: .zero)
        let coordinator = ScanCoordinator(
            sessionManager: AdapterSessionManager(client: mock, initializer: mock),
            diagnostics: mock
        )

        await coordinator.begin(vehicleID: UUID())

        #expect(coordinator.failure == nil)
        #expect(coordinator.result?.status == .serviceSoon)
        #expect(coordinator.progress == 1)
        #expect(coordinator.stages.map(\.stage) == ScanStage.allCases)
        #expect(coordinator.stages.allSatisfy {
            switch $0.state {
            case .completed, .limited: true
            default: false
            }
        })
    }

    @Test
    func connectionFailureStopsAtConnectingWithTypedContext() async {
        let mock = ScriptedMockAdapter(scenario: .connectionFailure, delay: .zero)
        let coordinator = ScanCoordinator(
            sessionManager: AdapterSessionManager(client: mock, initializer: mock),
            diagnostics: mock
        )

        await coordinator.begin(vehicleID: UUID())

        #expect(coordinator.result == nil)
        #expect(coordinator.failure?.stage == .connecting)
        #expect(coordinator.failure?.code == .connectionFailed)
        #expect(coordinator.failure?.allowsRetry == true)
        #expect(coordinator.stages[0].state == .completed(detail: "Found Veepeak OBDCheck BLE"))
        if case .failed = coordinator.stages[1].state {
            #expect(Bool(true))
        } else {
            Issue.record("Connecting stage should contain the failure")
        }
        #expect(coordinator.stages.dropFirst(2).allSatisfy { $0.state == .waiting })
    }

    @Test
    func incompleteDataCompletesTransportAndReturnsUnableToAssess() async {
        let mock = ScriptedMockAdapter(scenario: .incompleteData, delay: .zero)
        let coordinator = ScanCoordinator(
            sessionManager: AdapterSessionManager(client: mock, initializer: mock),
            diagnostics: mock
        )

        await coordinator.begin(vehicleID: UUID())

        #expect(coordinator.failure == nil)
        #expect(coordinator.result?.status == .unableToAssess)
        #expect(coordinator.result?.score == nil)
    }
}
