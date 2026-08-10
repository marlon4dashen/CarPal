import Foundation
import Testing
@testable import CarPal

struct VehicleProfileEntityTests {
    @Test
    func entityRoundTripsDraftAndTimestamps() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let entity = VehicleProfileEntity(
            id: UUID(uuidString: "7C072D68-0100-4C41-B458-7E48F5FE1582")!,
            draft: .lexusNXPreview,
            createdAt: createdAt
        )

        #expect(entity.draft == .lexusNXPreview)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == createdAt)
    }

    @Test
    func updateReplacesDraftFieldsAndPreservesCreationDate() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000)
        let entity = VehicleProfileEntity(
            draft: .lexusNXPreview,
            createdAt: createdAt
        )
        let replacement = VehicleDraft(
            nickname: "Family RX",
            make: "Lexus",
            model: "RX",
            modelYear: "2023",
            variant: "RX 350",
            vinOrPlate: "NEWPLATE",
            mileage: "32000",
            trim: "Premium",
            colour: "Nori Green Pearl",
            fuelType: "Gasoline"
        )

        entity.update(from: replacement, at: updatedAt)

        #expect(entity.draft == replacement)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }
}
