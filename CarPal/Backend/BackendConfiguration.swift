import Foundation

enum BackendConfiguration {
    static var vehicleIdentificationClient: any VehicleIdentificationClient {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-useMockAdapter") {
            return RegistrationBackendFixture.client()
        }
#endif
        return URLSessionVehicleIdentificationClient(baseURL: baseURL)
    }

    static var diagnosticParsingClient: any DiagnosticParsingClient {
        URLSessionDiagnosticParsingClient(baseURL: baseURL)
    }

    private static var baseURL: URL {
        if let configured = ProcessInfo.processInfo.environment["CARPAL_BACKEND_URL"],
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }
}

#if DEBUG
private enum RegistrationBackendFixture {
    static func client() -> FixtureVehicleIdentificationClient {
        let eligibility = APIDiagnosticEligibility(
            profileID: "lexus-nx300-2020-na",
            profileVersion: "1.0.0",
            quickScan: .supported,
            healthScan: .supported,
            collectionPlan: "nx300-2020-v1",
            ruleSet: "nx300-2020-rules-v1",
            limitations: ["Simulator fixture; no external VIN request was made."]
        )
        return FixtureVehicleIdentificationClient(
            decodeResponse: APIVehicleDecodeResponse(
                schemaVersion: "1",
                candidate: candidate,
                decodeWarnings: [],
                eligibility: eligibility
            ),
            resolveResponse: APIDiagnosticProfileResolveResponse(
                schemaVersion: "1",
                eligibility: eligibility
            )
        )
    }

    private static var candidate: APIVehicleCandidate {
        APIVehicleCandidate(
            vin: attribute("JTJYARBZ0L2000001", source: .obd),
            modelYear: APIVehicleAttribute(
                value: 2020,
                source: .user,
                requiresConfirmation: false
            ),
            make: attribute("LEXUS"),
            model: attribute("NX 300"),
            series: attribute("NX 300"),
            vehicleType: attribute("MULTIPURPOSE PASSENGER VEHICLE"),
            bodyClass: attribute("Sport Utility Vehicle"),
            engineModel: attribute("8AR-FTS"),
            engineConfiguration: attribute("In-Line"),
            displacementL: APIVehicleAttribute(
                value: 2.0,
                source: .vinDecoder,
                requiresConfirmation: false
            ),
            engineCylinders: APIVehicleAttribute(
                value: 4,
                source: .vinDecoder,
                requiresConfirmation: false
            ),
            fuelTypePrimary: attribute("Gasoline"),
            fuelTypeSecondary: attribute(nil),
            driveType: attribute("4WD/4-Wheel Drive/4x4"),
            transmissionStyle: attribute("Automatic"),
            manufacturer: attribute("TOYOTA MOTOR NORTH AMERICA, INC"),
            plantCountry: attribute("JAPAN")
        )
    }

    private static func attribute(
        _ value: String?,
        source: APIAttributeSource = .vinDecoder
    ) -> APIVehicleAttribute<String> {
        APIVehicleAttribute(
            value: value,
            source: source,
            requiresConfirmation: value == nil
        )
    }
}
#endif
