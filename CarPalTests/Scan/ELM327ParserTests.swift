import Testing
@testable import CarPal

struct ELM327ParserTests {
    private let parser = ELM327Parser()

    @Test
    func parsesPIDPayloadFromSpacedResponse() {
        let payload = parser.payload(for: 0x01, pid: 0x0C, in: "41 0C 1A F8")
        #expect(payload == [0x1A, 0xF8])
    }

    @Test
    func parsesSupportedPIDBitmap() {
        let supported = parser.supportedPIDs(base: 0x00, response: "41 00 18 1B 80 13")
        #expect(supported.contains(0x04))
        #expect(supported.contains(0x05))
        #expect(supported.contains(0x0C))
        #expect(supported.contains(0x0D))
    }

    @Test
    func unionsSupportedPIDsFromMultipleECUsWithCANHeaders() {
        let response = """
        7E9 06 41 00 00 00 00 01
        7E8 06 41 00 18 18 00 01
        """

        let supported = parser.supportedPIDs(base: 0x00, response: response)

        #expect(supported.contains(0x04))
        #expect(supported.contains(0x05))
        #expect(supported.contains(0x0C))
        #expect(supported.contains(0x0D))
        #expect(supported.contains(0x20))
    }

    @Test
    func parsesPIDPayloadWithCANHeaderAndFrameLength() {
        let payload = parser.payload(for: 0x01, pid: 0x0C, in: "7E8 04 41 0C 1A F8")
        #expect(payload == [0x1A, 0xF8])
    }

    @Test
    func parsesCompactHeaderlessResponse() {
        let payload = parser.payload(for: 0x01, pid: 0x05, in: "41057B")
        #expect(payload == [0x7B])
    }

    @Test
    func parsesCompactResponseWithStandardCANHeader() {
        let payload = parser.payload(for: 0x01, pid: 0x0C, in: "7E804410C1AF8")
        #expect(payload == [0x1A, 0xF8])
    }

    @Test
    func parsesAndDeduplicatesDiagnosticTroubleCodes() {
        let codes = parser.troubleCodes(from: "43 01 71 03 00 00 00")
        #expect(codes.map(\.code) == ["P0171", "P0300"])
        #expect(codes.first?.summary == "System too lean (bank 1)")
    }

    @Test
    func combinesTroubleCodesReportedByMultipleECUs() {
        let response = "7E8 04 43 01 71 00 00\n7E9 04 43 03 00 00 00"
        let codes = parser.troubleCodes(from: response)
        #expect(codes.map(\.code) == ["P0171", "P0300"])
    }
}
