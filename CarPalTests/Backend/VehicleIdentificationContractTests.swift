import Foundation
import Testing
@testable import CarPal

struct VehicleIdentificationContractTests {
    @Test
    func decodesBackendSnakeCaseContract() throws {
        let response = try JSONDecoder.carPalAPI().decode(
            APIVehicleDecodeResponse.self,
            from: Data(Self.decodeFixture.utf8)
        )

        #expect(response.candidate.model.value == "NX 300")
        #expect(response.candidate.model.source == .vinDecoder)
        #expect(response.eligibility.profileID == "lexus-nx300-2020-na")
        #expect(response.eligibility.healthScan == .supported)
    }

    @Test
    func fixtureClientRecordsRequests() async throws {
        let response = try JSONDecoder.carPalAPI().decode(
            APIVehicleDecodeResponse.self,
            from: Data(Self.decodeFixture.utf8)
        )
        let client = FixtureVehicleIdentificationClient(
            decodeResponse: response,
            resolveResponse: APIDiagnosticProfileResolveResponse(
                schemaVersion: "1",
                eligibility: response.eligibility
            )
        )
        let request = APIVehicleDecodeRequest(
            vin: "JTJYARBZ0L2000001",
            modelYear: 2020,
            obdIdentity: APIOBDIdentity(
                calibrationIDs: [],
                ecuNames: [],
                supportedModes: [1, 9]
            ),
            adapter: APIAdapterMetadata(
                model: "veepeak-obdcheck-ble",
                protocol: nil,
                market: "CA"
            )
        )

        let result = await client.decodeVehicle(request)

        #expect(result.eligibility.healthScan == .supported)
        #expect(await client.decodeRequests == [request])
    }

    @Test
    func encodesOBDIdentityWithBackendContractKeys() throws {
        let identity = APIOBDIdentity(
            calibrationIDs: ["CAL-TEST"],
            ecuNames: ["ECM"],
            supportedModes: [1, 9]
        )

        let data = try JSONEncoder.carPalAPI().encode(identity)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["calibration_ids"] as? [String] == ["CAL-TEST"])
        #expect(object["ecu_names"] as? [String] == ["ECM"])
        #expect(object["supported_modes"] as? [Int] == [1, 9])
    }

    private static let attributeNull = """
        {"value":null,"source":"VIN_DECODER","requires_confirmation":true}
        """

    private static let decodeFixture = """
        {
          "schema_version":"1",
          "candidate":{
            "vin":{"value":"JTJYARBZ0L2000001","source":"OBD","requires_confirmation":false},
            "model_year":{"value":2020,"source":"USER","requires_confirmation":false},
            "make":{"value":"LEXUS","source":"VIN_DECODER","requires_confirmation":false},
            "model":{"value":"NX 300","source":"VIN_DECODER","requires_confirmation":false},
            "series":\(attributeNull),"vehicle_type":\(attributeNull),"body_class":\(attributeNull),
            "engine_model":\(attributeNull),"engine_configuration":\(attributeNull),
            "displacement_l":{"value":null,"source":"VIN_DECODER","requires_confirmation":true},
            "engine_cylinders":{"value":null,"source":"VIN_DECODER","requires_confirmation":true},
            "fuel_type_primary":\(attributeNull),"fuel_type_secondary":\(attributeNull),
            "drive_type":\(attributeNull),"transmission_style":\(attributeNull),
            "manufacturer":\(attributeNull),"plant_country":\(attributeNull)
          },
          "decode_warnings":[],
          "eligibility":{
            "profile_id":"lexus-nx300-2020-na","profile_version":"1.0.0",
            "quick_scan":"supported","health_scan":"supported",
            "collection_plan":"nx300-2020-v1","rule_set":"nx300-2020-rules-v1","limitations":[]
          }
        }
        """
}
