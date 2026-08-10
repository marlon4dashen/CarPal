import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ScanHistoryStore {
    enum StoreError: Error {
        case invalidStoredResult
    }

    private let modelContext: ModelContext
    private(set) var results: [ScanResult] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(vehicleID: UUID) throws {
        let descriptor = FetchDescriptor<ScanHistoryEntity>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor).filter { $0.vehicleID == vehicleID }
        let decoded = entities.compactMap(\.result)
        guard decoded.count == entities.count else {
            throw StoreError.invalidStoredResult
        }
        results = decoded
    }

    @discardableResult
    func save(_ result: ScanResult) throws -> ScanResult {
        let entity = try ScanHistoryEntity(result: result)
        modelContext.insert(entity)
        try modelContext.save()
        results.removeAll { $0.id == result.id }
        results.append(result)
        results.sort { $0.scannedAt > $1.scannedAt }
        return result
    }

    func result(id: UUID) -> ScanResult? {
        results.first { $0.id == id }
    }

    func clear(vehicleID: UUID) throws {
        let descriptor = FetchDescriptor<ScanHistoryEntity>()
        for entity in try modelContext.fetch(descriptor) where entity.vehicleID == vehicleID {
            modelContext.delete(entity)
        }
        try modelContext.save()
        results.removeAll()
    }
}
