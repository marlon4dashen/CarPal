import Foundation

enum VehicleFormField: String, CaseIterable, Hashable, Sendable {
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

    var accessibilityLabel: String {
        switch self {
        case .nickname:
            "Vehicle nickname"
        case .make:
            "Vehicle make"
        case .model:
            "Vehicle model"
        case .modelYear:
            "Vehicle model year"
        case .variant:
            "Vehicle variant"
        case .vinOrPlate:
            "VIN or licence plate"
        case .mileage:
            "Current mileage"
        case .trim:
            "Vehicle trim"
        case .colour:
            "Vehicle colour"
        case .fuelType:
            "Vehicle fuel type"
        }
    }

    var next: VehicleFormField? {
        guard let index = Self.allCases.firstIndex(of: self) else {
            return nil
        }

        let nextIndex = Self.allCases.index(after: index)
        return nextIndex < Self.allCases.endIndex ? Self.allCases[nextIndex] : nil
    }
}

struct VehicleFormFieldErrors: Equatable, Sendable {
    private var messages: [VehicleFormField: String]

    init(_ messages: [VehicleFormField: String] = [:]) {
        self.messages = messages
    }

    subscript(field: VehicleFormField) -> String? {
        messages[field]
    }

    var isEmpty: Bool {
        messages.isEmpty
    }
}
