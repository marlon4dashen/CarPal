import Foundation

nonisolated struct VehicleVisualAsset: Equatable, Sendable {
    let baseAssetName: String
    let paintMaskAssetName: String
    let description: String
    let isModelMatched: Bool
}

nonisolated enum VehicleVisualCatalog {
    static func asset(for vehicle: VehicleDraft) -> VehicleVisualAsset {
        let make = normalized(vehicle.make)
        let model = normalized(vehicle.model)

        if make == "lexus",
           vehicle.modelYear == "2020",
           model == "nx" || model.hasPrefix("nx ") {
            return VehicleVisualAsset(
                baseAssetName: "LexusNX2020",
                paintMaskAssetName: "LexusNX2020PaintMask",
                description: "2020 Lexus NX model preview",
                isModelMatched: true
            )
        }

        return VehicleVisualAsset(
            baseAssetName: "DefaultVehicle",
            paintMaskAssetName: "DefaultVehiclePaintMask",
            description: "Generic vehicle preview for unsupported model",
            isModelMatched: false
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
