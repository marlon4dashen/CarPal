import SwiftUI

enum CarPalColor {
    static let canvas = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let canvasHighlight = Color(red: 1.00, green: 0.98, blue: 0.93)
    static let surface = Color(red: 1.00, green: 0.99, blue: 0.96)
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let secondaryInk = Color(red: 0.38, green: 0.35, blue: 0.29)
    static let accent = Color(red: 0.76, green: 0.25, blue: 0.10)
    static let accentPressed = Color(red: 0.61, green: 0.18, blue: 0.07)
    static let petrol = Color(red: 0.09, green: 0.29, blue: 0.27)
    static let warning = Color(red: 0.69, green: 0.40, blue: 0.03)
    static let danger = Color(red: 0.64, green: 0.12, blue: 0.10)
    static let hairline = Color(red: 0.13, green: 0.12, blue: 0.10).opacity(0.10)
}

enum CarPalSpacing {
    static let xSmall: CGFloat = 6
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

enum CarPalRadius {
    static let control: CGFloat = 14
    static let card: CGFloat = 22
    static let hero: CGFloat = 28
}

extension Font {
    static let carPalEyebrow = Font.system(.caption, design: .rounded, weight: .bold)
    static let carPalTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let carPalSection = Font.system(.title3, design: .rounded, weight: .bold)
    static let carPalMetric = Font.system(.title2, design: .rounded, weight: .heavy)
    static let carPalBody = Font.system(.body, design: .rounded, weight: .regular)
}

struct CarPalCanvas: View {
    var body: some View {
        LinearGradient(
            colors: [
                CarPalColor.canvasHighlight,
                CarPalColor.canvas,
                CarPalColor.canvas.opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

