import Testing
import UIKit
@testable import CarPal

struct VehicleArtworkCatalogTests {
    @Test
    func resolvesTheCuratedLexusNXAssetPair() {
        let asset = VehicleVisualCatalog.asset(for: .lexusNXPreview)

        #expect(asset.baseAssetName == "LexusNX2020")
        #expect(asset.paintMaskAssetName == "LexusNX2020PaintMask")
        #expect(asset.isModelMatched)
    }

    @Test
    func matchingIgnoresCaseAndExtraWhitespace() {
        var vehicle = VehicleDraft.lexusNXPreview
        vehicle.make = "  LEXUS "
        vehicle.model = "  nx "

        #expect(VehicleVisualCatalog.asset(for: vehicle).isModelMatched)
    }

    @Test
    func unsupportedVehicleUsesCompleteDefaultAssetPair() {
        let vehicle = VehicleDraft(
            nickname: "My BMW",
            make: "BMW",
            model: "330i",
            modelYear: "2021"
        )

        let asset = VehicleVisualCatalog.asset(for: vehicle)

        #expect(asset.baseAssetName == "DefaultVehicle")
        #expect(asset.paintMaskAssetName == "DefaultVehiclePaintMask")
        #expect(!asset.isModelMatched)
    }

    @Test
    func modelYearResolvesItsBodyPhaseArtwork() {
        var vehicle = VehicleDraft.lexusNXPreview
        vehicle.modelYear = "2021"

        let asset = VehicleVisualCatalog.asset(for: vehicle)

        #expect(asset.baseAssetName == "LexusNX2020")
        #expect(asset.isModelMatched)
    }

    @MainActor
    @Test
    func everyResolvedAssetNameExistsInTheAppBundle() {
        for asset in Self.allVisualAssets {
            #expect(asset.isModelMatched)
            #expect(UIImage(named: asset.baseAssetName) != nil)
            #expect(UIImage(named: asset.paintMaskAssetName) != nil)
        }
    }

    @MainActor
    @Test
    func everyPaintMaskMatchesItsBaseArtworkAndHasUsefulCoverage() throws {
        for asset in Self.allVisualAssets + [Self.defaultVisualAsset] {
            let baseImage = try #require(UIImage(named: asset.baseAssetName)?.cgImage)
            let maskImage = try #require(UIImage(named: asset.paintMaskAssetName)?.cgImage)

            #expect(maskImage.width == baseImage.width)
            #expect(maskImage.height == baseImage.height)
            #expect(maskImage.width == 1_536)
            #expect(maskImage.height == 1_024)

            let statistics = try MaskStatistics(image: maskImage)
            #expect(statistics.darkFraction > 0.70)
            #expect(statistics.darkFraction < 0.90)
            #expect(statistics.brightFraction > 0.10)
            #expect(statistics.brightFraction < 0.30)
            #expect(statistics.transitionFraction < 0.03)
            #expect(statistics.maximumChroma <= 24)
        }
    }

    private static let allVisualAssets = [
        ("NX", "2015"), ("NX", "2018"), ("NX", "2022"),
        ("RX", "2015"), ("RX", "2016"), ("RX", "2020"), ("RX", "2023")
    ].map { series, year in
        VehicleVisualCatalog.asset(for: VehicleDraft(
            make: "Lexus",
            model: series,
            modelYear: year
        ))
    }

    private static let defaultVisualAsset = VehicleVisualCatalog.asset(for: VehicleDraft(
        make: "Unsupported",
        model: "Unsupported",
        modelYear: "2020"
    ))
}

private struct MaskStatistics {
    let darkFraction: Double
    let brightFraction: Double
    let transitionFraction: Double
    let maximumChroma: UInt8

    init(image: CGImage) throws {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try #require(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var darkCount = 0
        var brightCount = 0
        var transitionCount = 0
        var maximumChroma: UInt8 = 0
        let sampleStride = 8
        var sampleCount = 0

        for y in stride(from: 0, to: height, by: sampleStride) {
            for x in stride(from: 0, to: width, by: sampleStride) {
                let offset = y * bytesPerRow + x * 4
                let red = pixels[offset]
                let green = pixels[offset + 1]
                let blue = pixels[offset + 2]
                let minimum = min(red, green, blue)
                let maximum = max(red, green, blue)
                maximumChroma = max(maximumChroma, maximum - minimum)

                if maximum < 32 {
                    darkCount += 1
                } else if minimum > 223 {
                    brightCount += 1
                } else {
                    transitionCount += 1
                }
                sampleCount += 1
            }
        }

        darkFraction = Double(darkCount) / Double(sampleCount)
        brightFraction = Double(brightCount) / Double(sampleCount)
        transitionFraction = Double(transitionCount) / Double(sampleCount)
        self.maximumChroma = maximumChroma
    }
}
