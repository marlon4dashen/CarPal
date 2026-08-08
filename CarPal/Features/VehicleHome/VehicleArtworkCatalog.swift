import Foundation

nonisolated struct VehicleArtwork: Equatable, Sendable {
    let assetName: String
    let description: String
}

nonisolated enum VehicleArtworkCatalog {
    static func artwork(for vehicle: VehicleDraft) -> VehicleArtwork? {
        let make = normalized(vehicle.make)
        let model = normalized(vehicle.model)

        guard make == "lexus",
              vehicle.modelYear == "2020",
              model == "nx" || model.hasPrefix("nx ")
        else {
            return nil
        }

        return VehicleArtwork(
            assetName: "LexusNX2020",
            description: "2020 Lexus NX model preview"
        )
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }
}
