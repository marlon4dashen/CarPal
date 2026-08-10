import Foundation

nonisolated struct LexusVehicleCatalog: Decodable, Sendable {
    struct NamedValue: Decodable, Equatable, Sendable {
        let id: String
        let name: String
    }

    struct BodyPhase: Decodable, Equatable, Sendable {
        let id: String
        let seriesID: String
        let years: [Int]
        let visualKey: String
    }

    struct PaintColor: Decodable, Equatable, Sendable {
        let id: String
        let name: String
        let paintCode: String
        let renderToken: String
    }

    struct ColorSet: Decodable, Equatable, Sendable {
        let id: String
        let colorIDs: [String]
    }

    struct Trim: Decodable, Equatable, Sendable {
        let id: String
        let name: String
        let colorSetID: String
        let years: [Int]?

        func isAvailable(in year: Int) -> Bool {
            years?.contains(year) ?? true
        }
    }

    struct Offering: Decodable, Equatable, Sendable {
        let seriesID: String
        let years: [Int]
        let variantID: String
        let variantName: String
        let fuelType: String
        let sourceURL: String
        let trims: [Trim]
    }

    let schemaVersion: Int
    let market: String
    let make: NamedValue
    let series: [NamedValue]
    let bodyPhases: [BodyPhase]
    let colors: [PaintColor]
    let colorSets: [ColorSet]
    let offerings: [Offering]
}

nonisolated enum LexusVehicleCatalogError: Error, Equatable, Sendable {
    case missingResource
    case unsupportedSchema(Int)
    case invalidMarket(String)
    case invalidReference(String)
    case missingCoverage(seriesID: String, year: Int)
}

nonisolated struct LexusVehicleCatalogRepository: Sendable {
    static let shared: Self = {
        do {
            return try Self.load()
        } catch {
            fatalError("Lexus vehicle catalog is invalid: \(error)")
        }
    }()

    let catalog: LexusVehicleCatalog

    init(catalog: LexusVehicleCatalog) throws {
        self.catalog = catalog
        try validate()
    }

    static func load(bundle: Bundle = .main) throws -> Self {
        let resourceURL = bundle.url(
            forResource: "LexusVehicleCatalog",
            withExtension: "json",
            subdirectory: "Resources"
        ) ?? bundle.url(forResource: "LexusVehicleCatalog", withExtension: "json")

        guard let resourceURL else {
            throw LexusVehicleCatalogError.missingResource
        }

        let data = try Data(contentsOf: resourceURL)
        return try Self(catalog: JSONDecoder().decode(LexusVehicleCatalog.self, from: data))
    }

    var makeName: String { catalog.make.name }

    var seriesNames: [String] {
        catalog.series.map(\.name)
    }

    func years(forSeries seriesName: String) -> [String] {
        guard let seriesID = seriesID(for: seriesName) else { return [] }
        return catalog.offerings
            .filter { $0.seriesID == seriesID }
            .flatMap(\.years)
            .uniqued()
            .sorted(by: >)
            .map(String.init)
    }

    func variants(forSeries seriesName: String, year: String) -> [String] {
        offerings(forSeries: seriesName, year: year)
            .map(\.variantName)
            .uniqued()
    }

    func trims(for draft: VehicleDraft) -> [String] {
        guard let year = Int(draft.modelYear),
              let offering = offering(
                seriesName: draft.model,
                year: year,
                variantName: draft.variant
              ) else { return [] }

        return offering.trims.filter { $0.isAvailable(in: year) }.map(\.name)
    }

    func colors(for draft: VehicleDraft) -> [LexusVehicleCatalog.PaintColor] {
        guard let year = Int(draft.modelYear),
              let offering = offering(
                seriesName: draft.model,
                year: year,
                variantName: draft.variant
              ),
              let trim = offering.trims.first(where: {
                $0.isAvailable(in: year) && normalized($0.name) == normalized(draft.trim)
              }),
              let colorSet = catalog.colorSets.first(where: { $0.id == trim.colorSetID })
        else { return [] }

        let colorsByID = Dictionary(uniqueKeysWithValues: catalog.colors.map { ($0.id, $0) })
        return colorSet.colorIDs.compactMap { colorsByID[$0] }
    }

    func fuelType(for draft: VehicleDraft) -> String? {
        guard let year = Int(draft.modelYear) else { return nil }
        return offering(
            seriesName: draft.model,
            year: year,
            variantName: draft.variant
        )?.fuelType
    }

    func bodyPhase(for draft: VehicleDraft) -> LexusVehicleCatalog.BodyPhase? {
        guard normalized(draft.make) == normalized(makeName),
              let seriesID = seriesID(for: draft.model),
              let year = Int(draft.modelYear) else { return nil }
        return catalog.bodyPhases.first {
            $0.seriesID == seriesID && $0.years.contains(year)
        }
    }

    func renderColor(for profileValue: String) -> VehiclePaintColor {
        let token = catalog.colors.first {
            normalized($0.name) == normalized(profileValue)
        }?.renderToken ?? profileValue
        return VehiclePaintColor(profileValue: token)
    }

    func contains(_ draft: VehicleDraft) -> Bool {
        guard normalized(draft.make) == normalized(makeName),
              let year = Int(draft.modelYear),
              let offering = offering(
                seriesName: draft.model,
                year: year,
                variantName: draft.variant
              ),
              offering.trims.contains(where: {
                $0.isAvailable(in: year) && normalized($0.name) == normalized(draft.trim)
              }),
              colors(for: draft).contains(where: {
                normalized($0.name) == normalized(draft.colour)
              }),
              normalized(offering.fuelType) == normalized(draft.fuelType)
        else { return false }
        return true
    }

    func canonicalSeries(_ value: String) -> String? {
        catalog.series.first { normalized($0.name) == normalized(value) }?.name
    }

    func canonicalVariant(_ value: String, series: String, year: String) -> String? {
        variants(forSeries: series, year: year).first {
            normalized($0) == normalized(value)
        }
    }

    private func offerings(forSeries seriesName: String, year: String) -> [LexusVehicleCatalog.Offering] {
        guard let seriesID = seriesID(for: seriesName), let year = Int(year) else { return [] }
        return catalog.offerings.filter {
            $0.seriesID == seriesID && $0.years.contains(year)
        }
    }

    private func offering(
        seriesName: String,
        year: Int,
        variantName: String
    ) -> LexusVehicleCatalog.Offering? {
        offerings(forSeries: seriesName, year: String(year)).first {
            normalized($0.variantName) == normalized(variantName)
        }
    }

    private func seriesID(for name: String) -> String? {
        catalog.series.first { normalized($0.name) == normalized(name) }?.id
    }

    private func validate() throws {
        guard catalog.schemaVersion == 1 else {
            throw LexusVehicleCatalogError.unsupportedSchema(catalog.schemaVersion)
        }
        guard catalog.market == "CA" else {
            throw LexusVehicleCatalogError.invalidMarket(catalog.market)
        }

        let seriesIDs = Set(catalog.series.map(\.id))
        let phaseSeriesIDs = Set(catalog.bodyPhases.map(\.seriesID))
        guard phaseSeriesIDs.isSubset(of: seriesIDs) else {
            throw LexusVehicleCatalogError.invalidReference("body phase series")
        }

        let colorIDs = Set(catalog.colors.map(\.id))
        let colorSetIDs = Set(catalog.colorSets.map(\.id))
        guard catalog.colorSets.allSatisfy({ Set($0.colorIDs).isSubset(of: colorIDs) }) else {
            throw LexusVehicleCatalogError.invalidReference("color set color")
        }
        guard catalog.offerings.allSatisfy({ offering in
            seriesIDs.contains(offering.seriesID)
                && !offering.sourceURL.isEmpty
                && !offering.trims.isEmpty
                && offering.trims.allSatisfy { colorSetIDs.contains($0.colorSetID) }
        }) else {
            throw LexusVehicleCatalogError.invalidReference("offering")
        }

        for seriesID in seriesIDs {
            for year in 2015...2026 {
                guard catalog.offerings.contains(where: {
                    $0.seriesID == seriesID && $0.years.contains(year)
                }), catalog.bodyPhases.contains(where: {
                    $0.seriesID == seriesID && $0.years.contains(year)
                }) else {
                    throw LexusVehicleCatalogError.missingCoverage(
                        seriesID: seriesID,
                        year: year
                    )
                }
            }
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }
}

nonisolated private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
