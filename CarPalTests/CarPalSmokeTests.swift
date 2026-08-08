import Testing
@testable import CarPal

struct CarPalSmokeTests {
    @Test
    func previewVehicleHasRequiredIdentity() {
        let vehicle = VehicleDraft.lexusNXPreview

        #expect(!vehicle.nickname.isEmpty)
        #expect(!vehicle.make.isEmpty)
        #expect(!vehicle.model.isEmpty)
        #expect(!vehicle.modelYear.isEmpty)
    }
}
