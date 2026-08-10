import Testing
@testable import CarPal

struct LexusVehicleCatalogTests {
    private let catalog = LexusVehicleCatalogRepository.shared

    @Test
    func catalogCoversBothSeriesFrom2015Through2026() {
        #expect(catalog.makeName == "Lexus")
        #expect(catalog.seriesNames == ["NX", "RX"])

        for series in catalog.seriesNames {
            #expect(Set(catalog.years(forSeries: series)) == Set((2015...2026).map(String.init)))
        }
    }

    @Test
    func variantTrimColorAndFuelDependOnUpstreamSelection() {
        var draft = VehicleDraft.lexusNXPreview

        #expect(catalog.variants(forSeries: "NX", year: "2020") == ["NX 300", "NX 300h"])
        #expect(catalog.trims(for: draft).contains("Luxury"))
        #expect(catalog.colors(for: draft).map(\.name).contains("Atomic Silver"))
        #expect(catalog.fuelType(for: draft) == "Gasoline")

        draft.variant = "NX 300h"
        draft.trim = "Executive"
        draft.fuelType = "Hybrid"
        #expect(catalog.fuelType(for: draft) == "Hybrid")
    }

    @Test
    func modernVariantsAndBodyPhasesResolveAtBoundaries() {
        #expect(catalog.variants(forSeries: "NX", year: "2025").contains("NX 250"))
        #expect(!catalog.variants(forSeries: "NX", year: "2026").contains("NX 250"))
        #expect(catalog.variants(forSeries: "RX", year: "2024").contains("RX 450h+"))

        var draft = VehicleDraft.lexusNXPreview
        draft.modelYear = "2022"
        #expect(catalog.bodyPhase(for: draft)?.id == "nx-2022-2026")
        draft.model = "RX"
        draft.modelYear = "2015"
        #expect(catalog.bodyPhase(for: draft)?.id == "rx-2015")
    }

    @Test
    func officialColorsMapToRuntimePaintFamilies() {
        #expect(catalog.renderColor(for: "Atomic Silver") == .silver)
        #expect(catalog.renderColor(for: "Caviar") == .black)
        #expect(catalog.renderColor(for: "Nori Green Pearl") == .green)
    }
}
