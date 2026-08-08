import SwiftUI

struct VehicleHeroView: View {
    let vehicle: VehicleDraft

    private var artwork: VehicleArtwork? {
        VehicleArtworkCatalog.artwork(for: vehicle)
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
                Text(artwork == nil ? "VEHICLE PROFILE" : "CURATED MODEL PREVIEW")
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

            Image(systemName: artwork == nil ? "car.side.fill" : "checkmark.seal.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(artwork == nil ? .white.opacity(0.62) : CarPalColor.accent)
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

            if let artwork {
                Image(artwork.assetName)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(artwork.description)
                    .padding(.horizontal, -10)
                    .padding(.bottom, 4)
            } else {
                genericFallback
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 205)
    }

    private var genericFallback: some View {
        VStack(spacing: CarPalSpacing.small) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 94, weight: .regular))
                .symbolRenderingMode(.palette)
                .foregroundStyle(vehicleBodyColor, .black.opacity(0.44))

            Text("Model artwork is not available yet")
                .font(.carPalEyebrow)
                .foregroundStyle(.white.opacity(0.68))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Model artwork is not available for (vehicleDescription)")
        .padding(.bottom, CarPalSpacing.medium)
    }

    private var footer: some View {
        HStack(spacing: CarPalSpacing.small) {
            Label(
                vehicle.colour.isEmpty ? "Colour not set" : vehicle.colour,
                systemImage: "paintpalette.fill"
            )

            Spacer(minLength: CarPalSpacing.small)

            if artwork != nil {
                Label("Model matched", systemImage: "sparkles")
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
        [vehicle.modelYear, vehicle.make, vehicle.model]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var vehicleBodyColor: Color {
        let colour = vehicle.colour.lowercased()

        if colour.contains("silver") || colour.contains("gray") || colour.contains("grey") {
            return Color(red: 0.68, green: 0.71, blue: 0.72)
        } else if colour.contains("black") {
            return Color(red: 0.14, green: 0.14, blue: 0.13)
        } else if colour.contains("white") {
            return Color(red: 0.91, green: 0.91, blue: 0.88)
        } else if colour.contains("blue") {
            return Color(red: 0.14, green: 0.34, blue: 0.58)
        } else if colour.contains("green") {
            return Color(red: 0.16, green: 0.42, blue: 0.30)
        } else if colour.contains("red") {
            return Color(red: 0.76, green: 0.17, blue: 0.09)
        } else {
            return CarPalColor.accent
        }
    }
}
