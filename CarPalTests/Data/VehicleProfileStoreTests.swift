import Foundation
import SwiftData
import Testing
@testable import CarPal

@MainActor
struct VehicleProfileStoreTests {
    @Test
    func createAndUpdatePersistOneVehicle() throws {
        let container = try makeContainer()
        let store = VehicleProfileStore(modelContext: container.mainContext)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000)

        let created = try store.create(from: .lexusNXPreview, at: createdAt)
        var replacement = VehicleDraft.lexusNXPreview
        replacement.nickname = "Updated Lexus"
        let updated = try store.update(with: replacement, at: updatedAt)

        #expect(created.id == updated.id)
        #expect(store.vehicle?.draft == replacement)
        #expect(store.vehicle?.createdAt == createdAt)
        #expect(store.vehicle?.updatedAt == updatedAt)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<VehicleProfileEntity>()) == 1)
    }

    @Test
    func createRejectsASecondVehicle() throws {
        let container = try makeContainer()
        let store = VehicleProfileStore(modelContext: container.mainContext)
        try store.create(from: .lexusNXPreview)

        #expect(throws: VehicleProfileStore.StoreError.profileAlreadyExists) {
            try store.create(from: .lexusNXPreview)
        }
    }

    @Test
    func loadKeepsMostRecentlyUpdatedVehicleAndRemovesDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let older = VehicleProfileEntity(
            draft: .lexusNXPreview,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        var newerDraft = VehicleDraft.lexusNXPreview
        newerDraft.nickname = "Newest"
        let newer = VehicleProfileEntity(
            draft: newerDraft,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let store = VehicleProfileStore(modelContext: context)
        try store.load()

        #expect(store.vehicle?.draft == newerDraft)
        #expect(try context.fetchCount(FetchDescriptor<VehicleProfileEntity>()) == 1)
    }

    @Test
    func loadDeletesLegacyUnsupportedVehicle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(VehicleProfileEntity(draft: VehicleDraft(
            nickname: "Legacy vehicle",
            make: "BMW",
            model: "330i",
            modelYear: "2021",
            variant: "330i xDrive",
            vinOrPlate: "LEGACY",
            mileage: "1000",
            trim: "xDrive",
            colour: "Blue",
            fuelType: "Gasoline"
        )))
        try context.save()

        let store = VehicleProfileStore(modelContext: context)
        try store.load()

        #expect(store.vehicle == nil)
        #expect(try context.fetchCount(FetchDescriptor<VehicleProfileEntity>()) == 0)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: VehicleProfileEntity.self,
            configurations: configuration
        )
    }
}
