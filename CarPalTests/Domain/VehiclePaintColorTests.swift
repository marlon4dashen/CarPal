import Testing
@testable import CarPal

struct VehiclePaintColorTests {
    @Test(arguments: VehiclePaintColor.allCases)
    func paletteValuesRoundTripThroughProfileText(_ paintColor: VehiclePaintColor) {
        #expect(VehiclePaintColor(profileValue: paintColor.rawValue) == paintColor)
    }

    @Test
    func legacyNamesNormalizeToPaletteValues() {
        #expect(VehiclePaintColor(profileValue: "Atomic Silver") == .silver)
        #expect(VehiclePaintColor(profileValue: "dark grey") == .gray)
    }

    @Test
    func missingOrUnknownColourFallsBackToNeutralSilver() {
        #expect(VehiclePaintColor(profileValue: "") == .silver)
        #expect(VehiclePaintColor(profileValue: "Purple") == .silver)
    }
}
