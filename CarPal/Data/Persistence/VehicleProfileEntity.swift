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

    func update(from draft: VehicleDraft, at date: Date = .now) {
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
        updatedAt = date
    }
}
