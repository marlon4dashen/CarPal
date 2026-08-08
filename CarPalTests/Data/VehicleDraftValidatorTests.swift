import Testing
@testable import CarPal

struct VehicleDraftValidatorTests {
    private let validator = VehicleDraftValidator(currentYear: 2026)

    @Test
    func validDraftHasNoErrors() {
        #expect(validator.validate(.lexusNXPreview).isEmpty)
    }

    @Test
    func requiredFieldsReturnFieldSpecificErrors() {
        let errors = validator.validate(VehicleDraft())

        #expect(
            Set(errors.keys) == Set([
                .nickname,
                .make,
                .model,
                .modelYear,
                .vinOrPlate,
                .mileage
            ])
        )
        #expect(errors[.nickname]?.field == .nickname)
        #expect(errors[.vinOrPlate]?.message == "VIN or licence plate is required.")
    }

    @Test(arguments: ["twenty", "02020", "1885", "2028"])
    func invalidModelYearsAreRejected(_ modelYear: String) {
        var draft = VehicleDraft.lexusNXPreview
        draft.modelYear = modelYear

        #expect(validator.validate(draft)[.modelYear] != nil)
    }

    @Test(arguments: ["-1", "unknown", "NaN", "inf"])
    func invalidMileagesAreRejected(_ mileage: String) {
        var draft = VehicleDraft.lexusNXPreview
        draft.mileage = mileage

        #expect(validator.validate(draft)[.mileage] != nil)
    }

    @Test(arguments: ["0", "48200", "48200.5"])
    func nonnegativeNumericMileagesAreAccepted(_ mileage: String) {
        var draft = VehicleDraft.lexusNXPreview
        draft.mileage = mileage

        #expect(validator.validate(draft)[.mileage] == nil)
    }

    @Test
    func unsupportedMakeAndModelAreRejected() {
        var draft = VehicleDraft.lexusNXPreview
        draft.make = "Mercedes-Benz"
        draft.model = "EQS 450+"

        let errors = validator.validate(draft)

        #expect(errors[.make]?.message == "Select a supported make.")
        #expect(errors[.model]?.message == "Select a model supported for this make.")
    }

    @Test
    func modelMustBelongToSelectedMake() {
        var draft = VehicleDraft.lexusNXPreview
        draft.make = "BMW"

        #expect(validator.validate(draft)[.model] != nil)
    }

    @Test
    func unsupportedOptionalSelectionsAreRejected() {
        var draft = VehicleDraft.lexusNXPreview
        draft.colour = "Purple"
        draft.fuelType = "Steam"

        let errors = validator.validate(draft)

        #expect(errors[.colour] != nil)
        #expect(errors[.fuelType] != nil)
    }
}
