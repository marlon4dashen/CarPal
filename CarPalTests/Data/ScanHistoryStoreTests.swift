import Foundation
import SwiftData
import Testing
@testable import CarPal

@MainActor
struct ScanHistoryStoreTests {
    @Test
    func saveAndLoadPreserveStoredDecisionAndFindings() throws {
        let container = try makeContainer()
        let vehicleID = UUID()
        let result = makeResult(vehicleID: vehicleID, scannedAt: Date(timeIntervalSince1970: 1_000))
        let store = ScanHistoryStore(modelContext: container.mainContext)

        try store.save(result)

        let reloaded = ScanHistoryStore(modelContext: container.mainContext)
        try reloaded.load(vehicleID: vehicleID)

        #expect(reloaded.results == [result])
        #expect(reloaded.result(id: result.id) == result)
    }

    @Test
    func historyIsNewestFirstAndScopedToVehicle() throws {
        let container = try makeContainer()
        let vehicleID = UUID()
        let store = ScanHistoryStore(modelContext: container.mainContext)
        let older = makeResult(vehicleID: vehicleID, scannedAt: Date(timeIntervalSince1970: 1_000))
        let newer = makeResult(vehicleID: vehicleID, scannedAt: Date(timeIntervalSince1970: 2_000))
        let other = makeResult(vehicleID: UUID(), scannedAt: Date(timeIntervalSince1970: 3_000))

        try store.save(older)
        try store.save(other)
        try store.save(newer)
        try store.load(vehicleID: vehicleID)

        #expect(store.results.map(\.id) == [newer.id, older.id])
    }

    @Test
    func clearDeletesOnlyTheUnregisteredVehiclesHistory() throws {
        let container = try makeContainer()
        let vehicleID = UUID()
        let otherVehicleID = UUID()
        let store = ScanHistoryStore(modelContext: container.mainContext)
        try store.save(makeResult(vehicleID: vehicleID, scannedAt: .now))
        try store.save(makeResult(vehicleID: otherVehicleID, scannedAt: .now))
        try store.load(vehicleID: vehicleID)

        try store.clear(vehicleID: vehicleID)

        #expect(store.results.isEmpty)
        let entities = try container.mainContext.fetch(FetchDescriptor<ScanHistoryEntity>())
        #expect(entities.map(\.vehicleID) == [otherVehicleID])
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ScanHistoryEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeResult(vehicleID: UUID, scannedAt: Date) -> ScanResult {
        ScanResult(
            id: UUID(),
            vehicleID: vehicleID,
            scannedAt: scannedAt,
            status: .serviceSoon,
            score: 68,
            completeness: 1,
            summary: "A diagnostic code was detected.",
            whyItMatters: "It should be inspected.",
            action: .arrangeDiagnosticInspection,
            findings: [AssessmentFinding(
                id: UUID(),
                title: "Engine code",
                detail: "P0171 was reported.",
                whyItMatters: "Fuel mixture may be affected.",
                severity: .attention,
                technicalDetail: "P0171"
            )],
            unavailableData: [],
            technicalSummary: "engineRPM: 750",
            blockingReason: nil
        )
    }
}
