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
    func parsesMode09SupportedPIDBitmap() {
        let supported = parser.supportedPIDs(
            base: 0x00,
            requestMode: 0x09,
            response: "49 00 50 40 00 00"
        )

        #expect(supported.contains(0x02))
        #expect(supported.contains(0x04))
        #expect(supported.contains(0x0A))
    }

    @Test
    func parsesMultiframeMode09VIN() {
        let response = """
        0: 49 02 01 4A 54 4A 59 41 52
        1: 42 5A 30 4C 32 30 30 30
        2: 30 30 31
        """

        #expect(parser.vehicleInformationStrings(pid: 0x02, response: response) == [
            "JTJYARBZ0L2000001"
        ])
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

}
