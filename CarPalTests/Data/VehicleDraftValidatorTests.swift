import Testing
@testable import CarPal

struct VehicleDraftValidatorTests {
    private let validator = VehicleDraftValidator()

    @Test
    func validCatalogDraftHasNoErrors() {
        #expect(validator.validate(.lexusNXPreview).isEmpty)
    }

    @Test
    func emptyDraftReturnsEveryRequiredIdentityError() {
        let errors = validator.validate(VehicleDraft())

        #expect(Set(errors.keys) == Set([
            .nickname, .make, .model, .modelYear, .variant, .vinOrPlate,
            .mileage, .trim, .colour, .fuelType
        ]))
        #expect(errors[.vinOrPlate]?.message == "VIN or licence plate is required.")
    }

    @Test(arguments: ["2014", "2027", "twenty"])
    func unavailableModelYearsAreRejected(_ modelYear: String) {
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
    func mismatchedDependentSelectionsAreRejected() {
        var draft = VehicleDraft.lexusNXPreview
        draft.make = "BMW"
        draft.variant = "RX 500h"
        draft.colour = "Purple"
        draft.fuelType = "Diesel"

        let errors = validator.validate(draft)
        #expect(errors[.make] != nil)
        #expect(errors[.variant] != nil)
        #expect(errors[.colour] != nil)
        #expect(errors[.fuelType] != nil)
    }
}
