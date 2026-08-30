import Foundation

enum APIAttributeSource: String, Codable, Sendable {
    case obd = "OBD"
    case vinDecoder = "VIN_DECODER"
    case oemDatabase = "OEM_DATABASE"
    case user = "USER"
}

enum APISupportLevel: String, Codable, Sendable {
    case supported
    case limited
    case unsupported
}

enum APIOperatingCondition: String, Codable, Sendable {
    case unknown
    case warmUp = "warm_up"
    case warmIdle = "warm_idle"
    case driving
}

struct APIVehicleAttribute<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    let value: Value?
    let source: APIAttributeSource
    let requiresConfirmation: Bool
}

struct APIOBDIdentity: Codable, Equatable, Sendable {
    let calibrationIDs: [String]
    let ecuNames: [String]
    let supportedModes: [Int]

    private enum CodingKeys: String, CodingKey {
        case calibrationIDs = "calibrationIds"
        case ecuNames
        case supportedModes
    }
}

struct APIAdapterMetadata: Codable, Equatable, Sendable {
    let model: String
    let `protocol`: String?
    let market: String?
}

struct APIVehicleCandidate: Codable, Equatable, Sendable {
    let vin: APIVehicleAttribute<String>
    let modelYear: APIVehicleAttribute<Int>
    let make: APIVehicleAttribute<String>
    let model: APIVehicleAttribute<String>
    let series: APIVehicleAttribute<String>
    let vehicleType: APIVehicleAttribute<String>
    let bodyClass: APIVehicleAttribute<String>
    let engineModel: APIVehicleAttribute<String>
    let engineConfiguration: APIVehicleAttribute<String>
    let displacementL: APIVehicleAttribute<Double>
    let engineCylinders: APIVehicleAttribute<Int>
    let fuelTypePrimary: APIVehicleAttribute<String>
    let fuelTypeSecondary: APIVehicleAttribute<String>
    let driveType: APIVehicleAttribute<String>
    let transmissionStyle: APIVehicleAttribute<String>
    let manufacturer: APIVehicleAttribute<String>
    let plantCountry: APIVehicleAttribute<String>
}

struct APIDiagnosticEligibility: Codable, Equatable, Sendable {
    let profileID: String?
    let profileVersion: String?
    let quickScan: APISupportLevel
    let healthScan: APISupportLevel
    let collectionPlan: String?
    let ruleSet: String?
    let limitations: [String]

    private enum CodingKeys: String, CodingKey {
        case profileID = "profileId"
        case profileVersion
        case quickScan
        case healthScan
        case collectionPlan
        case ruleSet
        case limitations
    }
}

struct APIVehicleDecodeRequest: Codable, Equatable, Sendable {
    let schemaVersion: String
    let vin: String
    let modelYear: Int
    let obdIdentity: APIOBDIdentity
    let adapter: APIAdapterMetadata

    init(
        vin: String,
        modelYear: Int,
        obdIdentity: APIOBDIdentity,
        adapter: APIAdapterMetadata,
        schemaVersion: String = "1"
    ) {
        self.schemaVersion = schemaVersion
        self.vin = vin
        self.modelYear = modelYear
        self.obdIdentity = obdIdentity
        self.adapter = adapter
    }
}

struct APIVehicleDecodeResponse: Codable, Equatable, Sendable {
    let schemaVersion: String
    let candidate: APIVehicleCandidate
    let decodeWarnings: [String]
    let eligibility: APIDiagnosticEligibility
}

struct APIDiagnosticProfileResolveRequest: Codable, Equatable, Sendable {
    let schemaVersion: String
    let identity: APIVehicleCandidate
    let obdIdentity: APIOBDIdentity
    let adapter: APIAdapterMetadata

    init(
        identity: APIVehicleCandidate,
        obdIdentity: APIOBDIdentity,
        adapter: APIAdapterMetadata,
        schemaVersion: String = "1"
    ) {
        self.schemaVersion = schemaVersion
        self.identity = identity
        self.obdIdentity = obdIdentity
        self.adapter = adapter
    }
}

struct APIDiagnosticProfileResolveResponse: Codable, Equatable, Sendable {
    let schemaVersion: String
    let eligibility: APIDiagnosticEligibility
}

struct APIDiagnosticObservation: Codable, Equatable, Sendable {
    let schemaVersion: String
    let sequenceNumber: Int
    let recordedAt: Date
    let mode: Int
    let pid: String
    let value: APIObservationValue
    let unit: String?
    let operatingCondition: APIOperatingCondition
}

enum APIObservationValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case number(Double)
    case boolean(Bool)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .boolean(value) }
        else if let value = try? container.decode(Int.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else { self = .string(try container.decode(String.self)) }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        }
    }
}

struct APIErrorResponse: Codable, Equatable, Sendable {
    struct Body: Codable, Equatable, Sendable {
        let code: String
        let message: String
        let retryable: Bool
    }

    let error: Body
}

extension JSONDecoder {
    static func carPalAPI() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static func carPalAPI() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
