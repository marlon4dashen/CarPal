import Testing
import UIKit
@testable import CarPal

struct VehicleArtworkCatalogTests {
    @Test
    func resolvesTheCuratedLexusNXAssetPair() {
        let asset = VehicleVisualCatalog.asset(for: .lexusNXPreview)

        #expect(asset.baseAssetName == "LexusNX2020")
        #expect(asset.paintMaskAssetName == "LexusNX2020PaintMask")
        #expect(asset.isModelMatched)
    }

    @Test
    func matchingIgnoresCaseAndExtraWhitespace() {
        var vehicle = VehicleDraft.lexusNXPreview
        vehicle.make = "  LEXUS "
        vehicle.model = "NX   300"

        #expect(VehicleVisualCatalog.asset(for: vehicle).isModelMatched)
    }

    @Test
    func unsupportedVehicleUsesCompleteDefaultAssetPair() {
        let vehicle = VehicleDraft(
            nickname: "My BMW",
            make: "BMW",
            model: "330i",
            modelYear: "2021"
        )

        let asset = VehicleVisualCatalog.asset(for: vehicle)

        #expect(asset.baseAssetName == "DefaultVehicle")
        #expect(asset.paintMaskAssetName == "DefaultVehiclePaintMask")
        #expect(!asset.isModelMatched)
    }

    @Test
    func differentModelYearDoesNotReuseTheWrongArtwork() {
        var vehicle = VehicleDraft.lexusNXPreview
        vehicle.modelYear = "2021"

        #expect(!VehicleVisualCatalog.asset(for: vehicle).isModelMatched)
    }

    @MainActor
    @Test
    func everyResolvedAssetNameExistsInTheAppBundle() {
        let exact = VehicleVisualCatalog.asset(for: .lexusNXPreview)
        var unsupported = VehicleDraft.lexusNXPreview
        unsupported.modelYear = "2021"
        let fallback = VehicleVisualCatalog.asset(for: unsupported)

        for asset in [exact, fallback] {
            #expect(UIImage(named: asset.baseAssetName) != nil)
            #expect(UIImage(named: asset.paintMaskAssetName) != nil)
        }
    }
}
