import Foundation

struct VehicleDraft: Equatable, Sendable {
    var nickname = ""
    var make = ""
    var model = ""
    var modelYear = ""
    var vinOrPlate = ""
    var mileage = ""
    var trim = ""
    var colour = ""
    var fuelType = ""
}

extension VehicleDraft {
    static let lexusNXPreview = VehicleDraft(
        nickname: "My Lexus",
        make: "Lexus",
        model: "NX 300",
        modelYear: "2020",
        vinOrPlate: "CARPAL",
        mileage: "48200",
        trim: "Luxury",
        colour: "Atomic Silver",
        fuelType: "Gasoline"
    )
}
