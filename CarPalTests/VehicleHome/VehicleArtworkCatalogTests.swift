import Testing
@testable import CarPal

struct VehicleArtworkCatalogTests {
    @Test
    func resolvesTheCuratedLexusNXAsset() {
        let artwork = VehicleArtworkCatalog.artwork(for: .lexusNXPreview)

        #expect(artwork?.assetName == "LexusNX2020")
    }

    @Test
    func matchingIgnoresCaseAndExtraWhitespace() {
        var vehicle = VehicleDraft.lexusNXPreview
        vehicle.make = "  LEXUS "
        vehicle.model = "NX   300"

        #expect(VehicleArtworkCatalog.artwork(for: vehicle) != nil)
    }

    @Test
    func unsupportedVehicleDoesNotClaimModelArtwork() {
        let vehicle = VehicleDraft(
            nickname: "My BMW",
            make: "BMW",
            model: "330i",
            modelYear: "2021"
        )

        #expect(VehicleArtworkCatalog.artwork(for: vehicle) == nil)
    }

    @Test
    func differentModelYearDoesNotReuseTheWrongArtwork() {
        var vehicle = VehicleDraft.lexusNXPreview
        vehicle.modelYear = "2021"

        #expect(VehicleArtworkCatalog.artwork(for: vehicle) == nil)
    }
}
