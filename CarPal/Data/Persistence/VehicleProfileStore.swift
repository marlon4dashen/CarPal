import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class VehicleProfileStore {
    enum StoreError: Error, Equatable {
        case profileAlreadyExists
        case profileNotFound
    }

    private let modelContext: ModelContext

    private(set) var vehicle: VehicleProfileEntity?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() throws {
        vehicle = try canonicalVehicle()

        if let vehicle, !LexusVehicleCatalogRepository.shared.contains(vehicle.draft) {
            modelContext.delete(vehicle)
            try modelContext.save()
            self.vehicle = nil
        }
    }

    @discardableResult
    func create(from draft: VehicleDraft, at date: Date = .now) throws -> VehicleProfileEntity {
        guard try canonicalVehicle() == nil else {
            throw StoreError.profileAlreadyExists
        }

        let vehicle = VehicleProfileEntity(draft: draft, createdAt: date)
        modelContext.insert(vehicle)
        try modelContext.save()
        self.vehicle = vehicle
        return vehicle
    }

    @discardableResult
    func update(with draft: VehicleDraft, at date: Date = .now) throws -> VehicleProfileEntity {
        guard let vehicle = try canonicalVehicle() else {
            throw StoreError.profileNotFound
        }

        vehicle.update(from: draft, at: date)
        try modelContext.save()
        self.vehicle = vehicle
        return vehicle
    }

    private func canonicalVehicle() throws -> VehicleProfileEntity? {
        var descriptor = FetchDescriptor<VehicleProfileEntity>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        descriptor.includePendingChanges = true

        let vehicles = try modelContext.fetch(descriptor)
        guard let canonical = vehicles.first else {
            return nil
        }

        if vehicles.count > 1 {
            for duplicate in vehicles.dropFirst() {
                modelContext.delete(duplicate)
            }
            try modelContext.save()
        }

        return canonical
    }
}
