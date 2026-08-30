import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class VehicleProfileStore {
    enum StoreError: Error, Equatable {
        case profileAlreadyExists
        case profileNotFound
        case invalidPresentationDetails
    }

    private let modelContext: ModelContext

    private(set) var vehicle: VehicleProfileEntity?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() throws {
        vehicle = try canonicalVehicle()
        if let vehicle, sanitizePresentationSelections(vehicle) {
            try modelContext.save()
        }
    }

    @discardableResult
    func create(
        from registration: ConfirmedVehicleRegistration,
        at date: Date = .now
    ) throws -> VehicleProfileEntity {
        guard try canonicalVehicle() == nil else {
            throw StoreError.profileAlreadyExists
        }

        let vehicle = VehicleProfileEntity(registration: registration, createdAt: date)
        modelContext.insert(vehicle)
        try modelContext.save()
        self.vehicle = vehicle
        return vehicle
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
    func updatePresentation(
        trim: String,
        colour: String,
        mileage: String,
        at date: Date = .now
    ) throws -> VehicleProfileEntity {
        guard let vehicle = try canonicalVehicle() else {
            throw StoreError.profileNotFound
        }

        var proposed = VehicleRegistrationDraft(profile: vehicle.draft)
        proposed.trim = trim
        proposed.colour = colour
        proposed.mileage = mileage
        let normalizedMileage = mileage.trimmingCharacters(in: .whitespacesAndNewlines)
        let mileageIsValid = normalizedMileage.isEmpty
            || Double(normalizedMileage).map { $0.isFinite && $0 >= 0 } == true
        guard mileageIsValid,
              VehicleRegistrationSelectionPolicy().validates(proposed) else {
            throw StoreError.invalidPresentationDetails
        }

        vehicle.trim = trim
        vehicle.colour = colour
        vehicle.mileage = mileage
        vehicle.updatedAt = date
        try modelContext.save()
        self.vehicle = vehicle
        return vehicle
    }

    func unregister() throws {
        guard let vehicle = try canonicalVehicle() else {
            throw StoreError.profileNotFound
        }

        modelContext.delete(vehicle)
        try modelContext.save()
        self.vehicle = nil
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

    private func sanitizePresentationSelections(_ vehicle: VehicleProfileEntity) -> Bool {
        let policy = VehicleRegistrationSelectionPolicy()
        let draft = VehicleRegistrationDraft(profile: vehicle.draft)
        let trims = policy.trimOptions(for: draft)
        var changed = false

        if !draft.trim.isEmpty, !trims.isEmpty, !trims.contains(draft.trim) {
            vehicle.trim = ""
            vehicle.colour = ""
            return true
        }

        let colours = policy.colourOptions(for: draft)
        if !draft.colour.isEmpty, !colours.contains(draft.colour) {
            vehicle.colour = ""
            changed = true
        }
        return changed
    }
}
