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
}
