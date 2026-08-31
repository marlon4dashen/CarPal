import Foundation
import Testing
@testable import CarPal

struct DiagnosticParsingContractTests {
    @Test
    func decodesTroubleCodeResponseAndGroupsForDisplay() throws {
        let response = try JSONDecoder.carPalAPI().decode(
            APITroubleCodeParseResponse.self,
            from: Data(Self.troubleCodeFixture.utf8)
        )

        #expect(response.report.confirmed.map(\.code) == ["P0171"])
        #expect(response.report.pending.map(\.code) == ["P0300"])
        #expect(response.report.permanent.isEmpty)
        #expect(response.catalogVersion == "1.0.0")
    }

    @Test
    func decodesReadinessResponseForDisplay() throws {
        let response = try JSONDecoder.carPalAPI().decode(
            APIReadinessParseResponse.self,
            from: Data(Self.readinessFixture.utf8)
        )

        #expect(response.report.isMILOn)
        #expect(response.report.confirmedDTCCount == 1)
        #expect(response.report.ignitionType == .spark)
        #expect(response.report.monitors.first?.name == "Misfire")
    }

    @Test
    func rawELMResponsesEncodeWithVersionedBackendContract() throws {
        let request = APITroubleCodeParseRequest(
            responses: APIRawTroubleCodeResponses(
                confirmed: "43 01 71",
                pending: "NO DATA",
                permanent: "NO DATA"
            )
        )
        let object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder.carPalAPI().encode(request)
            ) as? [String: Any]
        )

        #expect(object["schema_version"] as? String == "1")
        let responses = try #require(object["responses"] as? [String: String])
        #expect(responses["confirmed"] == "43 01 71")
    }

    private static let troubleCodeFixture = """
        {
          "schema_version":"1",
          "catalog_version":"1.0.0",
          "codes":[
            {"code":"P0171","summary":"System too lean","state":"confirmed"},
            {"code":"P0300","summary":"Misfire","state":"pending"}
          ]
        }
        """

    private static let readinessFixture = """
        {
          "schema_version":"1",
          "is_mil_on":true,
          "confirmed_dtc_count":1,
          "ignition_type":"spark",
          "monitors":[{"id":"misfire","name":"Misfire","is_complete":true}]
        }
        """
}
