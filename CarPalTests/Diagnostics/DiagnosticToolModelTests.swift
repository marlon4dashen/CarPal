import Testing
@testable import CarPal

@MainActor
struct DiagnosticToolModelTests {
    @Test
    func troubleCodeModelPublishesTypedReport() async {
        let report = TroubleCodeReport(
            confirmed: [DiagnosticTroubleCode(code: "P0171", summary: "Lean")]
        )
        let model = TroubleCodesToolModel(reader: TroubleCodeStub(result: .success(report)))

        await model.load()

        guard case let .loaded(loaded) = model.state else {
            Issue.record("Expected a loaded trouble-code report")
            return
        }
        #expect(loaded == report)
    }

    @Test
    func readinessModelMapsUnsupportedCapabilityToTypedFailure() async {
        let model = ReadinessToolModel(
            reader: ReadinessStub(result: .failure(DiagnosticCapabilityError.unsupported))
        )

        await model.load()

        guard case let .failed(failure) = model.state else {
            Issue.record("Expected a typed failure")
            return
        }
        #expect(failure == .unsupported)
    }
}

private struct TroubleCodeStub: TroubleCodeReading {
    let result: Result<TroubleCodeReport, any Error & Sendable>

    func readTroubleCodes() async throws -> TroubleCodeReport {
        try result.get()
    }
}

private struct ReadinessStub: ReadinessReading {
    let result: Result<ReadinessReport, any Error & Sendable>

    func readReadiness() async throws -> ReadinessReport {
        try result.get()
    }
}
