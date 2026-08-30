import Foundation
import SwiftData

@Model
final class VehicleProfileEntity {
    @Attribute(.unique) var id: UUID
    var nickname: String
    var make: String
    var model: String
    var modelYear: String
    var variant: String = ""
    var vinOrPlate: String
    var mileage: String
    var trim: String
    var colour: String
    var fuelType: String
    var vin: String = ""
    var engineModel: String = ""
    var driveType: String = ""
    var transmissionStyle: String = ""
    var makeSource: String = "USER"
    var modelSource: String = "USER"
    var modelYearSource: String = "USER"
    var engineSource: String = "USER"
    var fuelTypeSource: String = "USER"
    var driveTypeSource: String = "USER"
    var diagnosticProfileID: String = ""
    var diagnosticProfileVersion: String = ""
    var quickScanSupport: String = "unsupported"
    var healthScanSupport: String = "unsupported"
    var diagnosticLimitations: [String] = []
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        draft: VehicleDraft,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        nickname = draft.nickname
        make = draft.make
        model = draft.model
        modelYear = draft.modelYear
        variant = draft.variant
        vinOrPlate = draft.vinOrPlate
        mileage = draft.mileage
        trim = draft.trim
        colour = draft.colour
        fuelType = draft.fuelType
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    convenience init(
        id: UUID = UUID(),
        registration: ConfirmedVehicleRegistration,
        createdAt: Date = .now
    ) {
        self.init(id: id, draft: registration.draft, createdAt: createdAt)
        vin = registration.vin
        engineModel = registration.engineModel
        driveType = registration.driveType
        transmissionStyle = registration.transmissionStyle
        makeSource = registration.makeSource.rawValue
        modelSource = registration.modelSource.rawValue
        modelYearSource = registration.modelYearSource.rawValue
        engineSource = registration.engineSource.rawValue
        fuelTypeSource = registration.fuelTypeSource.rawValue
        driveTypeSource = registration.driveTypeSource.rawValue
        diagnosticProfileID = registration.diagnosticEligibility.profileID ?? ""
        diagnosticProfileVersion = registration.diagnosticEligibility.profileVersion ?? ""
        quickScanSupport = registration.diagnosticEligibility.quickScan.rawValue
        healthScanSupport = registration.diagnosticEligibility.healthScan.rawValue
        diagnosticLimitations = registration.diagnosticEligibility.limitations
    }

    var draft: VehicleDraft {
        VehicleDraft(
            nickname: nickname,
            make: make,
            model: model,
            modelYear: modelYear,
            variant: variant,
            vinOrPlate: vinOrPlate,
            mileage: mileage,
            trim: trim,
            colour: colour,
            fuelType: fuelType
        )
    }

}
