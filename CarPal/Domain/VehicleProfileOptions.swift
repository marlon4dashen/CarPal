import Foundation

nonisolated enum VehicleProfileOptions {
    static let makes = ["Lexus", "BMW"]

    static let colours = VehiclePaintColor.allCases.map(\.rawValue)

    static let fuelTypes = [
        "Gasoline", "Diesel", "Hybrid", "Plug-in Hybrid", "Electric", "Other"
    ]

    static func models(for make: String) -> [String] {
        switch canonicalMake(for: make) {
        case "Lexus":
            ["NX 300", "RX 350", "IS 300", "ES 350"]
        case "BMW":
            ["330i", "530i", "740i"]
        default:
            []
        }
    }

    static func canonicalMake(for value: String) -> String? {
        canonicalValue(for: value, in: makes)
    }

    static func canonicalModel(_ value: String, for make: String) -> String? {
        canonicalValue(for: value, in: models(for: make))
    }

    static func canonicalColour(for value: String) -> String? {
        let normalized = normalize(value)

        if normalized.contains("silver") {
            return "Silver"
        }
        if normalized.contains("gray") || normalized.contains("grey") {
            return "Gray"
        }

        return canonicalValue(for: value, in: colours)
    }

    static func canonicalFuelType(for value: String) -> String? {
        canonicalValue(for: value, in: fuelTypes)
    }

    private static func canonicalValue(for value: String, in options: [String]) -> String? {
        let normalized = normalize(value)
        return options.first { normalize($0) == normalized }
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }
}
