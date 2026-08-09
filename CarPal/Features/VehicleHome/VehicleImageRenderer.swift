import SwiftUI

struct VehicleImageRenderer: View {
    let asset: VehicleVisualAsset
    let paintColor: VehiclePaintColor

    var body: some View {
        ZStack {
            Image(asset.baseAssetName)
                .resizable()
                .scaledToFit()

            paintLayer
                .mask {
                    Image(asset.paintMaskAssetName)
                        .resizable()
                        .scaledToFit()
                        .luminanceToAlpha()
                }
        }
        .compositingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(paintColor.rawValue) \(asset.description)")
    }

    private var paintLayer: some View {
        recipe.color
            .opacity(recipe.opacity)
            .blendMode(recipe.blendMode)
    }

    private var recipe: PaintRecipe {
        switch paintColor {
        case .white:
            PaintRecipe(color: .white, opacity: 0.72, blendMode: .screen)
        case .black:
            PaintRecipe(color: .black, opacity: 0.72, blendMode: .multiply)
        case .silver:
            PaintRecipe(color: .white, opacity: 0, blendMode: .normal)
        case .gray:
            PaintRecipe(
                color: Color(red: 0.20, green: 0.22, blue: 0.23),
                opacity: 0.46,
                blendMode: .multiply
            )
        case .red:
            PaintRecipe(
                color: Color(red: 0.78, green: 0.08, blue: 0.035),
                opacity: 0.92,
                blendMode: .color
            )
        case .blue:
            PaintRecipe(
                color: Color(red: 0.04, green: 0.24, blue: 0.62),
                opacity: 0.92,
                blendMode: .color
            )
        case .green:
            PaintRecipe(
                color: Color(red: 0.035, green: 0.35, blue: 0.18),
                opacity: 0.92,
                blendMode: .color
            )
        }
    }
}

private struct PaintRecipe {
    let color: Color
    let opacity: Double
    let blendMode: BlendMode
}
