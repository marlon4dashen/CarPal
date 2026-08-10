import Foundation

nonisolated struct VehicleDraftValidator: Sendable {
    enum Field: Hashable, Sendable {
        case nickname
        case make
        case model
        case modelYear
        case variant
        case vinOrPlate
        case mileage
        case trim
        case colour
        case fuelType
    }

    struct FieldError: Error, Equatable, Sendable {
        let field: Field
        let message: String
    }

    private let catalog: LexusVehicleCatalogRepository

    init(catalog: LexusVehicleCatalogRepository = .shared) {
        self.catalog = catalog
    }

    func validate(_ draft: VehicleDraft) -> [Field: FieldError] {
        var errors: [Field: FieldError] = [:]

        require(draft.nickname, field: .nickname, label: "Nickname", errors: &errors)
        validateCatalogSelection(draft, errors: &errors)
        require(
            draft.vinOrPlate,
            field: .vinOrPlate,
            label: "VIN or licence plate",
            errors: &errors
        )
        validateMileage(draft.mileage, errors: &errors)

        return errors
    }

    private func validateCatalogSelection(
        _ draft: VehicleDraft,
        errors: inout [Field: FieldError]
    ) {
        if draft.make != catalog.makeName {
            errors[.make] = FieldError(field: .make, message: "Select Lexus.")
        }
        if catalog.canonicalSeries(draft.model) == nil {
            errors[.model] = FieldError(field: .model, message: "Select NX or RX.")
        }
        if !catalog.years(forSeries: draft.model).contains(draft.modelYear) {
            errors[.modelYear] = FieldError(
                field: .modelYear,
                message: "Select a supported model year."
            )
        }
        if catalog.canonicalVariant(
            draft.variant,
            series: draft.model,
            year: draft.modelYear
        ) == nil {
            errors[.variant] = FieldError(
                field: .variant,
                message: "Select an available variant."
            )
        }
        if !catalog.trims(for: draft).contains(draft.trim) {
            errors[.trim] = FieldError(field: .trim, message: "Select an available trim.")
        }
        if !catalog.colors(for: draft).map(\.name).contains(draft.colour) {
            errors[.colour] = FieldError(
                field: .colour,
                message: "Select an available exterior colour."
            )
        }
        if catalog.fuelType(for: draft) != draft.fuelType {
            errors[.fuelType] = FieldError(
                field: .fuelType,
                message: "Fuel type must match the selected variant."
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
