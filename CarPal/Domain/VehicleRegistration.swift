import Foundation

struct VehicleRegistrationDraft: Equatable, Sendable {
    var nickname = ""
    var vin = ""
    var modelYear = ""
    var make = ""
    var model = ""
    var engineModel = ""
    var fuelType = ""
    var driveType = ""
    var transmissionStyle = ""
    var trim = ""
    var colour = ""
    var mileage = ""

    var canDecode: Bool {
        vin.count == 17 && Int(modelYear).map { (1981...2100).contains($0) } == true
    }

    var canSave: Bool {
        canDecode
            && !nickname.trimmed.isEmpty
            && !make.trimmed.isEmpty
            && !model.trimmed.isEmpty
            && mileageIsValid
    }

    private var mileageIsValid: Bool {
        mileage.trimmed.isEmpty
            || Double(mileage.trimmed).map { $0.isFinite && $0 >= 0 } == true
    }

    var vehicleDraft: VehicleDraft {
        VehicleDraft(
            nickname: nickname.trimmed,
            make: make.trimmed,
            model: presentationSeries,
            modelYear: modelYear,
            variant: model.trimmed,
            vinOrPlate: vin,
            mileage: mileage.trimmed,
            trim: trim.trimmed,
            colour: colour.trimmed,
            fuelType: fuelType.trimmed
        )
    }

    private var presentationSeries: String {
        let normalized = model.uppercased()
        if normalized.contains("NX") { return "NX" }
        if normalized.contains("RX") { return "RX" }
        return model.trimmed
    }
}

extension VehicleRegistrationDraft {
    init(profile: VehicleDraft) {
        self.init(
            nickname: profile.nickname,
            vin: profile.vinOrPlate,
            modelYear: profile.modelYear,
            make: profile.make,
            model: profile.variant,
            fuelType: profile.fuelType,
            trim: profile.trim,
            colour: profile.colour,
            mileage: profile.mileage
        )
    }
}

struct ConfirmedVehicleRegistration: Equatable, Sendable {
    let draft: VehicleDraft
    let vin: String
    let engineModel: String
    let driveType: String
    let transmissionStyle: String
    let makeSource: APIAttributeSource
    let modelSource: APIAttributeSource
    let modelYearSource: APIAttributeSource
    let engineSource: APIAttributeSource
    let fuelTypeSource: APIAttributeSource
    let driveTypeSource: APIAttributeSource
    let diagnosticEligibility: APIDiagnosticEligibility
}

struct VehicleRegistrationSelectionPolicy: Sendable {
    private let catalog: LexusVehicleCatalogRepository

    init(catalog: LexusVehicleCatalogRepository = .shared) {
        self.catalog = catalog
    }

    func trimOptions(for draft: VehicleRegistrationDraft) -> [String] {
        catalog.trims(for: draft.vehicleDraft)
    }

    func colourOptions(for draft: VehicleRegistrationDraft) -> [String] {
        let trims = trimOptions(for: draft)
        if !trims.isEmpty {
            guard trims.contains(draft.trim) else { return [] }
            return catalog.colors(for: draft.vehicleDraft).map(\.name)
        }
        return VehiclePaintColor.allCases.map(\.rawValue)
    }

    func validates(_ draft: VehicleRegistrationDraft) -> Bool {
        let trims = trimOptions(for: draft)
        if !trims.isEmpty {
            return trims.contains(draft.trim)
                && colourOptions(for: draft).contains(draft.colour)
        }
        return draft.trim.trimmed.isEmpty
            && validatesOptional(draft.colour, against: colourOptions(for: draft))
    }

    private func validatesOptional(_ value: String, against options: [String]) -> Bool {
        value.trimmed.isEmpty || options.contains(value)
    }

}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
