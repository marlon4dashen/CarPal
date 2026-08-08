import Testing
@testable import CarPal

struct VehicleProfileOptionsTests {
    @Test
    func supportedModelsDependOnMake() {
        #expect(VehicleProfileOptions.models(for: "Lexus") == [
            "NX 300", "RX 350", "IS 300", "ES 350"
        ])
        #expect(VehicleProfileOptions.models(for: "BMW") == [
            "330i", "530i", "740i"
        ])
        #expect(VehicleProfileOptions.models(for: "") == [])
    }

    @Test
    func makeAndModelMatchingIsCaseAndWhitespaceInsensitive() {
        #expect(VehicleProfileOptions.canonicalMake(for: "  lexus ") == "Lexus")
        #expect(VehicleProfileOptions.canonicalModel("nx   300", for: "LEXUS") == "NX 300")
    }

    @Test
    func legacySilverNamesMapToTheSilverPaletteOption() {
        #expect(VehicleProfileOptions.canonicalColour(for: "Atomic Silver") == "Silver")
        #expect(VehicleProfileOptions.canonicalColour(for: "silver metallic") == "Silver")
    }
}
