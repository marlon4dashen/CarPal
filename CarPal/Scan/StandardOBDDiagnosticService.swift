import Foundation

actor StandardOBDDiagnosticService: ScanDiagnosticCapabilities, OBDSessionInitializing,
    VehicleIdentityReading, TroubleCodeReading, ReadinessReading {
    private let scheduler: OBDCommandScheduler
    private let diagnosticParsingClient: any DiagnosticParsingClient
    private let parser = ELM327Parser()
    private var supportedPIDs = Set<UInt8>()

    init(
        scheduler: OBDCommandScheduler,
        diagnosticParsingClient: any DiagnosticParsingClient
    ) {
        self.scheduler = scheduler
        self.diagnosticParsingClient = diagnosticParsingClient
    }

    func initializeSession() async throws {
        try await scheduler.withExclusiveLease(named: "Initialize vehicle session") { session in
            _ = try await session.execute(
                ELMCommandRequest("ATZ", timeout: .seconds(8), acceptsAnyResponse: true)
            )
            for command in ["ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"] {
                _ = try await session.execute(
                    ELMCommandRequest(command, acceptsAnyResponse: true)
                )
            }
            let identity = try await session.execute(
                ELMCommandRequest("ATI", acceptsAnyResponse: true)
            )
            guard identity.localizedCaseInsensitiveContains("ELM")
                    || identity.localizedCaseInsensitiveContains("OBD") else {
                throw OBDTransportError.invalidResponse(identity)
            }
        }
    }

    func discoverSupport() async throws -> OBDSupportReport {
        let parser = parser
        let discovered = try await scheduler.withExclusiveLease(named: "Discover capabilities") { session in
            var discovered = Set<UInt8>()
            var bases: [UInt8] = [0x00]
            while !bases.isEmpty {
                let base = bases.removeFirst()
                let response = try await session.execute(
                    ELMCommandRequest(String(format: "01%02X", base))
                )
                let page = parser.supportedPIDs(base: base, response: response)
                discovered.formUnion(page)
                let nextBase = base + 0x20
                if page.contains(nextBase), nextBase <= 0x40 {
                    bases.append(nextBase)
                }
            }
            return discovered
        }
        supportedPIDs = discovered

        let optional: [(UInt8, String)] = [
            (0x04, "Calculated engine load"), (0x0D, "Vehicle speed"),
            (0x11, "Throttle position"), (0x06, "Short-term fuel trim"),
            (0x07, "Long-term fuel trim")
        ]
        let required: [(UInt8, String)] = [
            (0x0C, "Engine RPM"), (0x05, "Coolant temperature"),
            (0x42, "Control-module voltage"), (0x03, "Fuel-system status")
        ]
        return OBDSupportReport(
            unavailableRequiredReadings: required.compactMap { discovered.contains($0.0) ? nil : $0.1 },
            unavailableOptionalReadings: optional.compactMap { discovered.contains($0.0) ? nil : $0.1 }
        )
    }

    func readVehicleIdentity() async throws -> OBDVehicleIdentity {
        let parser = parser
        return try await scheduler.withExclusiveLease(named: "Read vehicle identity") { session in
            var supportedModes: [Int] = []
            let protocolDescription = try? await session.execute(
                ELMCommandRequest("ATDP", acceptsAnyResponse: true)
            )

            if let response = try? await session.execute(
                ELMCommandRequest("0100", allowsNoData: true)
            ), !Self.isNoData(response), !parser.supportedPIDs(base: 0, response: response).isEmpty {
                supportedModes.append(1)
            }

            let mode09Response = try await session.execute(
                ELMCommandRequest("0900", allowsNoData: true)
            )
            let mode09PIDs = Self.isNoData(mode09Response)
                ? []
                : parser.supportedPIDs(base: 0, requestMode: 0x09, response: mode09Response)
            if !mode09PIDs.isEmpty {
                supportedModes.append(9)
            }

            let vin = try await Self.readMode09Strings(
                pid: 0x02,
                isSupported: mode09PIDs.contains(0x02),
                parser: parser,
                session: session
            ).first(where: Self.isValidVIN)
            let calibrationIDs = try await Self.readMode09Strings(
                pid: 0x04,
                isSupported: mode09PIDs.contains(0x04),
                parser: parser,
                session: session
            )
            let ecuNames = try await Self.readMode09Strings(
                pid: 0x0A,
                isSupported: mode09PIDs.contains(0x0A),
                parser: parser,
                session: session
            )

            return OBDVehicleIdentity(
                vin: vin,
                calibrationIDs: calibrationIDs,
                ecuNames: ecuNames,
                supportedModes: supportedModes,
                protocolDescription: protocolDescription
            )
        }
    }

    func retrieveCoreData() async throws -> RawScanData {
        let supportedPIDs = supportedPIDs
        let parser = parser
        let collected = try await scheduler.withExclusiveLease(named: "Legacy core scan") { session in
            var values: [SensorMetric: Double] = [:]

            values[.engineRPM] = try await Self.readMetric(
                pid: 0x0C, byteCount: 2, supportedPIDs: supportedPIDs,
                parser: parser, session: session
            ) { (Double($0[0]) * 256 + Double($0[1])) / 4 }
            values[.vehicleSpeed] = try await Self.readMetric(
                pid: 0x0D, supportedPIDs: supportedPIDs, parser: parser, session: session
            ) { Double($0[0]) }
            values[.coolantTemperature] = try await Self.readMetric(
                pid: 0x05, supportedPIDs: supportedPIDs, parser: parser, session: session
            ) { Double($0[0]) - 40 }
            values[.calculatedEngineLoad] = try await Self.readMetric(
                pid: 0x04, supportedPIDs: supportedPIDs, parser: parser, session: session
            ) { Double($0[0]) * 100 / 255 }
            values[.throttlePosition] = try await Self.readMetric(
                pid: 0x11, supportedPIDs: supportedPIDs, parser: parser, session: session
            ) { Double($0[0]) * 100 / 255 }
            values[.shortTermFuelTrim] = try await Self.readMetric(
                pid: 0x06, supportedPIDs: supportedPIDs, parser: parser, session: session
            ) { (Double($0[0]) - 128) * 100 / 128 }
            values[.longTermFuelTrim] = try await Self.readMetric(
                pid: 0x07, supportedPIDs: supportedPIDs, parser: parser, session: session
            ) { (Double($0[0]) - 128) * 100 / 128 }
            values[.controlModuleVoltage] = try await Self.readMetric(
                pid: 0x42, byteCount: 2, supportedPIDs: supportedPIDs,
                parser: parser, session: session
            ) { (Double($0[0]) * 256 + Double($0[1])) / 1_000 }

            let dtcResponse = try await session.execute(
                ELMCommandRequest("03", allowsNoData: true)
            )
            let fuelSystemStatus = try await Self.readFuelSystemStatus(
                supportedPIDs: supportedPIDs,
                parser: parser,
                session: session
            )
            let freezeFrameResponse = try? await session.execute(
                ELMCommandRequest("0202", allowsNoData: true)
            )
            let freezeFrameAvailable = freezeFrameResponse.map {
                !Self.isNoData($0) && parser.payload(for: 0x02, pid: 0x02, in: $0) != nil
            } ?? false

            return LegacyScanCollection(
                values: values.compactMapValues { $0 },
                confirmedDTCResponse: dtcResponse,
                fuelSystemStatus: fuelSystemStatus,
                freezeFrameAvailable: freezeFrameAvailable
            )
        }
        let parsedCodes = try await diagnosticParsingClient.parseTroubleCodes(
            APITroubleCodeParseRequest(
                responses: APIRawTroubleCodeResponses(
                    confirmed: collected.confirmedDTCResponse,
                    pending: "NO DATA",
                    permanent: "NO DATA"
                )
            )
        )
        return RawScanData(
            values: collected.values,
            troubleCodes: parsedCodes.report.confirmed,
            troubleCodesAvailable: true,
            fuelSystemStatus: collected.fuelSystemStatus,
            freezeFrameAvailable: collected.freezeFrameAvailable
        )
    }

    func readTroubleCodes() async throws -> TroubleCodeReport {
        let responses = try await scheduler.withExclusiveLease(named: "Read trouble codes") { session in
            let confirmed = try await session.execute(
                ELMCommandRequest("03", allowsNoData: true)
            )
            let pending = try await session.execute(
                ELMCommandRequest("07", allowsNoData: true)
            )
            let permanent = try await session.execute(
                ELMCommandRequest("0A", allowsNoData: true)
            )
            return APIRawTroubleCodeResponses(
                confirmed: confirmed,
                pending: pending,
                permanent: permanent
            )
        }
        return try await diagnosticParsingClient.parseTroubleCodes(
            APITroubleCodeParseRequest(responses: responses)
        ).report
    }

    func readReadiness() async throws -> ReadinessReport {
        let response = try await scheduler.withExclusiveLease(named: "Read emissions readiness") { session in
            try await session.execute(
                ELMCommandRequest("0101", allowsNoData: true)
            )
        }
        return try await diagnosticParsingClient.parseReadiness(
            APIReadinessParseRequest(response: response)
        ).report
    }

    nonisolated private static func readMetric(
        pid: UInt8,
        byteCount: Int = 1,
        supportedPIDs: Set<UInt8>,
        parser: ELM327Parser,
        session: OBDCommandSession,
        transform: @Sendable ([UInt8]) -> Double
    ) async throws -> Double? {
        guard supportedPIDs.contains(pid) else { return nil }
        let response = try await session.execute(
            ELMCommandRequest(String(format: "01%02X", pid), allowsNoData: true)
        )
        guard let payload = parser.payload(for: 0x01, pid: pid, in: response),
              payload.count >= byteCount else { return nil }
        return transform(Array(payload.prefix(byteCount)))
    }

    nonisolated private static func readMode09Strings(
        pid: UInt8,
        isSupported: Bool,
        parser: ELM327Parser,
        session: OBDCommandSession
    ) async throws -> [String] {
        guard isSupported else { return [] }
        let response = try await session.execute(
            ELMCommandRequest(String(format: "09%02X", pid), allowsNoData: true)
        )
        guard !isNoData(response) else { return [] }
        return parser.vehicleInformationStrings(pid: pid, response: response)
    }

    nonisolated private static func isValidVIN(_ value: String) -> Bool {
        value.count == 17
            && value.allSatisfy { character in
                character.isASCII
                    && (character.isNumber || character.isLetter)
                    && !["I", "O", "Q"].contains(character.uppercased())
            }
    }

    nonisolated private static func readFuelSystemStatus(
        supportedPIDs: Set<UInt8>,
        parser: ELM327Parser,
        session: OBDCommandSession
    ) async throws -> String? {
        guard supportedPIDs.contains(0x03) else { return nil }
        let response = try await session.execute(
            ELMCommandRequest("0103", allowsNoData: true)
        )
        guard let status = parser.payload(for: 0x01, pid: 0x03, in: response)?.first else {
            return nil
        }
        return switch status {
        case 1: "Open loop: insufficient engine temperature"
        case 2: "Closed loop"
        case 4: "Open loop: engine load or deceleration"
        case 8: "Open loop: system failure"
        case 16: "Closed loop with oxygen-sensor fault"
        default: "Status reported (0x\(String(format: "%02X", status)))"
        }
    }

    nonisolated private static func isNoData(_ response: String) -> Bool {
        response.localizedCaseInsensitiveContains("NO DATA")
    }
}

private struct LegacyScanCollection: Sendable {
    let values: [SensorMetric: Double]
    let confirmedDTCResponse: String
    let fuelSystemStatus: String?
    let freezeFrameAvailable: Bool
}
