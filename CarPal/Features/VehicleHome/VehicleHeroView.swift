import SwiftUI

struct VehicleHeroView: View {
    let vehicle: VehicleDraft

    private var visualAsset: VehicleVisualAsset {
        VehicleVisualCatalog.asset(for: vehicle)
    }

    private var paintColor: VehiclePaintColor {
        LexusVehicleCatalogRepository.shared.renderColor(for: vehicle.colour)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CarPalSpacing.small) {
            header
            vehicleVisual
            footer
        }
        .padding(.top, CarPalSpacing.large)
        .padding(.horizontal, CarPalSpacing.large)
        .padding(.bottom, CarPalSpacing.medium)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: CarPalRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CarPalRadius.hero, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: CarPalColor.petrol.opacity(0.24), radius: 24, y: 14)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: CarPalSpacing.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text(visualAsset.isModelMatched ? "CURATED MODEL PREVIEW" : "VEHICLE PROFILE")
                    .font(.carPalEyebrow)
                    .foregroundStyle(.white.opacity(0.68))

                Text(vehicle.nickname.isEmpty ? "My vehicle" : vehicle.nickname)
                    .font(.carPalTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(vehicleDescription)
                    .font(.carPalBody.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)

            Image(
                systemName: visualAsset.isModelMatched
                    ? "checkmark.seal.fill"
                    : "car.side.fill"
            )
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    visualAsset.isModelMatched
                        ? CarPalColor.accent
                        : .white.opacity(0.62)
                )
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var vehicleVisual: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(.black.opacity(0.30))
                .frame(width: 265, height: 26)
                .blur(radius: 10)
                .offset(y: -4)

            VehicleImageRenderer(asset: visualAsset, paintColor: paintColor)
                .padding(.horizontal, -10)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 205)
    }

    private var footer: some View {
        HStack(spacing: CarPalSpacing.small) {
            Label(
                vehicle.colour.isEmpty ? "Colour not set" : vehicle.colour,
                systemImage: "paintpalette.fill"
            )

            Spacer(minLength: CarPalSpacing.small)

            if visualAsset.isModelMatched {
                Label("Model matched", systemImage: "sparkles")
            } else {
                Text("Default preview")
            }
        }
        .font(.carPalEyebrow)
        .foregroundStyle(.white.opacity(0.74))
    }

    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.10, blue: 0.13),
                    CarPalColor.petrol,
                    Color(red: 0.08, green: 0.25, blue: 0.23)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(CarPalColor.accent.opacity(0.22))
                .frame(width: 220)
                .blur(radius: 10)
                .offset(x: 145, y: -105)

            Image(systemName: "diamond.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.035))
                .imageScale(.small)
        }
    }

    private var vehicleDescription: String {
        [vehicle.modelYear, vehicle.make, vehicle.variant]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

}
