import Foundation

nonisolated struct VehicleDraftValidator: Sendable {
    enum Field: Hashable, Sendable {
        case nickname
        case make
        case model
        case modelYear
        case vinOrPlate
        case mileage
        case colour
        case fuelType
    }

    struct FieldError: Error, Equatable, Sendable {
        let field: Field
        let message: String
    }

    private let currentYear: Int

    init(currentYear: Int = Calendar.current.component(.year, from: .now)) {
        self.currentYear = currentYear
    }

    func validate(_ draft: VehicleDraft) -> [Field: FieldError] {
        var errors: [Field: FieldError] = [:]

        require(draft.nickname, field: .nickname, label: "Nickname", errors: &errors)
        validateMake(draft.make, errors: &errors)
        validateModel(draft.model, make: draft.make, errors: &errors)
        validateModelYear(draft.modelYear, errors: &errors)
        require(
            draft.vinOrPlate,
            field: .vinOrPlate,
            label: "VIN or licence plate",
            errors: &errors
        )
        validateMileage(draft.mileage, errors: &errors)
        validateOptionalSelection(
            draft.colour,
            field: .colour,
            label: "Colour",
            canonicalValue: VehicleProfileOptions.canonicalColour,
            errors: &errors
        )
        validateOptionalSelection(
            draft.fuelType,
            field: .fuelType,
            label: "Fuel type",
            canonicalValue: VehicleProfileOptions.canonicalFuelType,
            errors: &errors
        )

        return errors
    }

    private func validateMake(
        _ value: String,
        errors: inout [Field: FieldError]
    ) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errors[.make] = FieldError(field: .make, message: "Make is required.")
            return
        }

        if VehicleProfileOptions.canonicalMake(for: value) == nil {
            errors[.make] = FieldError(field: .make, message: "Select a supported make.")
        }
    }

    private func validateModel(
        _ value: String,
        make: String,
        errors: inout [Field: FieldError]
    ) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errors[.model] = FieldError(field: .model, message: "Model is required.")
            return
        }

        if VehicleProfileOptions.canonicalModel(value, for: make) == nil {
            errors[.model] = FieldError(
                field: .model,
                message: "Select a model supported for this make."
            )
        }
    }

    private func validateOptionalSelection(
        _ value: String,
        field: Field,
        label: String,
        canonicalValue: (String) -> String?,
        errors: inout [Field: FieldError]
    ) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if canonicalValue(value) == nil {
            errors[field] = FieldError(
                field: field,
                message: "Select a supported \(label.lowercased())."
            )
        }
    }

    private func require(
        _ value: String,
        field: Field,
        label: String,
        errors: inout [Field: FieldError]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors[field] = FieldError(field: field, message: "\(label) is required.")
        }
    }

    private func validateModelYear(
        _ value: String,
        errors: inout [Field: FieldError]
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errors[.modelYear] = FieldError(
                field: .modelYear,
                message: "Model year is required."
            )
            return
        }

        guard let year = Int(trimmed), String(year) == trimmed else {
            errors[.modelYear] = FieldError(
                field: .modelYear,
                message: "Enter a valid four-digit model year."
            )
            return
        }

        let validYears = 1886...(currentYear + 1)
        if !validYears.contains(year) {
            errors[.modelYear] = FieldError(
                field: .modelYear,
                message: "Enter a model year between 1886 and \(currentYear + 1)."
            )
        }
    }

    private func validateMileage(
        _ value: String,
        errors: inout [Field: FieldError]
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errors[.mileage] = FieldError(
                field: .mileage,
                message: "Mileage is required."
            )
            return
        }

        guard let mileage = Double(trimmed), mileage.isFinite, mileage >= 0 else {
            errors[.mileage] = FieldError(
                field: .mileage,
                message: "Enter a nonnegative numeric mileage."
            )
            return
        }
    }
}
