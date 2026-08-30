import Foundation
import SwiftData
import Testing
@testable import CarPal

@MainActor
struct VehicleProfileStoreTests {
    @Test
    func createAndPresentationUpdatePersistOneVehicle() throws {
        let container = try makeContainer()
        let store = VehicleProfileStore(modelContext: container.mainContext)
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000)

        let created = try store.create(from: .lexusNXPreview, at: createdAt)
        let updated = try store.updatePresentation(
            trim: "Premium",
            colour: "Caviar",
            mileage: "50000",
            at: updatedAt
        )

        #expect(created.id == updated.id)
        #expect(store.vehicle?.nickname == VehicleDraft.lexusNXPreview.nickname)
        #expect(store.vehicle?.trim == "Premium")
        #expect(store.vehicle?.colour == "Caviar")
        #expect(store.vehicle?.mileage == "50000")
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
    func presentationUpdateCannotChangeDecodedIdentity() throws {
        let container = try makeContainer()
        let store = VehicleProfileStore(modelContext: container.mainContext)
        let vehicle = try store.create(from: .lexusNXPreview)
        let originalIdentity = (
            vehicle.make,
            vehicle.model,
            vehicle.modelYear,
            vehicle.variant,
            vehicle.vinOrPlate,
            vehicle.fuelType
        )

        try store.updatePresentation(
            trim: "Premium",
            colour: "Caviar",
            mileage: "50000"
        )

        #expect(store.vehicle?.trim == "Premium")
        #expect(store.vehicle?.colour == "Caviar")
        #expect(store.vehicle?.mileage == "50000")
        #expect(store.vehicle?.make == originalIdentity.0)
        #expect(store.vehicle?.model == originalIdentity.1)
        #expect(store.vehicle?.modelYear == originalIdentity.2)
        #expect(store.vehicle?.variant == originalIdentity.3)
        #expect(store.vehicle?.vinOrPlate == originalIdentity.4)
        #expect(store.vehicle?.fuelType == originalIdentity.5)
    }

    @Test
    func unregisterDeletesCurrentVehicleAndResetsStore() throws {
        let container = try makeContainer()
        let store = VehicleProfileStore(modelContext: container.mainContext)
        try store.create(from: .lexusNXPreview)

        try store.unregister()

        #expect(store.vehicle == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<VehicleProfileEntity>()) == 0)
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
    func loadRetainsBackendDecodedVehicleOutsideLegacyCatalog() throws {
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

        #expect(store.vehicle?.make == "BMW")
        #expect(try context.fetchCount(FetchDescriptor<VehicleProfileEntity>()) == 1)
    }

    @Test
    func loadClearsInvalidLegacyColourForCatalogVehicle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var draft = VehicleDraft.lexusNXPreview
        draft.colour = "Silver"
        context.insert(VehicleProfileEntity(draft: draft))
        try context.save()

        let store = VehicleProfileStore(modelContext: context)
        try store.load()

        #expect(store.vehicle?.trim == VehicleDraft.lexusNXPreview.trim)
        #expect(store.vehicle?.colour == "")
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: VehicleProfileEntity.self,
            configurations: configuration
        )
    }
}
