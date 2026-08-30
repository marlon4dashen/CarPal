import SwiftUI

struct CarPalCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
            .padding(CarPalSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CarPalColor.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: CarPalRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CarPalRadius.card, style: .continuous)
                    .stroke(CarPalColor.hairline, lineWidth: 1)
            }
            .shadow(color: CarPalColor.ink.opacity(0.06), radius: 14, y: 7)
    }
}

struct CarPalStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.carPalEyebrow)
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(tint.opacity(0.11))
            .clipShape(Capsule())
    }
}

struct CarPalMetric: View {
    let label: String
    let value: String
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(label.uppercased())
            }
            .font(.carPalEyebrow)
            .foregroundStyle(CarPalColor.secondaryInk)

            Text(value)
                .font(.carPalBody.weight(.semibold))
                .foregroundStyle(CarPalColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CarPalPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.carPalBody.weight(.bold))
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: CarPalRadius.control, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.985 : 1)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return CarPalColor.secondaryInk.opacity(0.48)
        }
        return isPressed ? CarPalColor.accentPressed : CarPalColor.accent
    }
}

struct CarPalQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.carPalBody.weight(.semibold))
            .foregroundStyle(CarPalColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(CarPalColor.surface.opacity(configuration.isPressed ? 0.62 : 0.88))
            .clipShape(RoundedRectangle(cornerRadius: CarPalRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CarPalRadius.control, style: .continuous)
                    .stroke(CarPalColor.hairline, lineWidth: 1)
            }
    }
}
