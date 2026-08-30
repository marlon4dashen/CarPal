import Testing
@testable import CarPal

struct VehicleRegistrationSelectionPolicyTests {
    @Test
    func supportedLexusRequiresExactCatalogColourForSelectedTrim() throws {
        let policy = VehicleRegistrationSelectionPolicy()
        var draft = VehicleRegistrationDraft(
            nickname: "My NX",
            vin: "JTJYARBZ0L2000001",
            modelYear: "2020",
            make: "LEXUS",
            model: "NX 300",
            engineModel: "8AR-FTS",
            fuelType: "Gasoline",
            driveType: "AWD",
            transmissionStyle: "Automatic"
        )
        draft.trim = try #require(policy.trimOptions(for: draft).first)

        #expect(!policy.colourOptions(for: draft).contains("Silver"))
        #expect(!policy.validates(draftWithColour("Silver", from: draft)))

        let validColour = try #require(policy.colourOptions(for: draft).first)
        #expect(policy.validates(draftWithColour(validColour, from: draft)))
    }

    private func draftWithColour(
        _ colour: String,
        from draft: VehicleRegistrationDraft
    ) -> VehicleRegistrationDraft {
        var result = draft
        result.colour = colour
        return result
    }

}
