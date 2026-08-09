import Foundation

nonisolated enum VehiclePaintColor: String, CaseIterable, Identifiable, Sendable {
    case white = "White"
    case black = "Black"
    case silver = "Silver"
    case gray = "Gray"
    case red = "Red"
    case blue = "Blue"
    case green = "Green"

    var id: Self { self }

    init(profileValue: String) {
        let normalized = profileValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.contains("silver") {
            self = .silver
        } else if normalized.contains("gray") || normalized.contains("grey") {
            self = .gray
        } else {
            self = Self.allCases.first {
                $0.rawValue.lowercased() == normalized
            } ?? .silver
        }
    }
}
