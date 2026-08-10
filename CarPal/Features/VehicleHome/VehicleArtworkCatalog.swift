nonisolated struct VehicleVisualAsset: Equatable, Sendable {
    let baseAssetName: String
    let paintMaskAssetName: String
    let description: String
    let isModelMatched: Bool
}

nonisolated enum VehicleVisualCatalog {
    static func asset(for vehicle: VehicleDraft) -> VehicleVisualAsset {
        if let phase = LexusVehicleCatalogRepository.shared.bodyPhase(for: vehicle) {
            return VehicleVisualAsset(
                baseAssetName: phase.visualKey,
                paintMaskAssetName: "\(phase.visualKey)PaintMask",
                description: "\(vehicle.modelYear) \(vehicle.variant) model preview",
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

}
