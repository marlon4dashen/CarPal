import Foundation
import Testing
@testable import CarPal

struct HealthAssessmentEngineTests {
    private let engine = HealthAssessmentEngine()

    @Test
    func completeDataWithDTCProducesCautiousScoredResult() {
        let result = engine.assess(
            scan: completeScan(codes: [
                DiagnosticTroubleCode(code: "P0171", summary: "System too lean")
            ]),
            vehicleID: UUID()
        )

        #expect(result.status == .serviceSoon)
        #expect(result.score == 68)
        #expect(result.action == .arrangeDiagnosticInspection)
        #expect(result.findings.first?.technicalDetail.contains("P0171") == true)
    }

    @Test
    func missingMinimumDataProducesUnableToAssessWithoutScore() {
        var values = completeValues
        values.removeValue(forKey: .engineRPM)
        values.removeValue(forKey: .controlModuleVoltage)
        let scan = NormalizedScan(
            values: values,
            troubleCodes: [],
            troubleCodesAvailable: true,
            fuelSystemStatus: nil,
            freezeFrameAvailable: false
        )

        let result = engine.assess(scan: scan, vehicleID: UUID())

        #expect(result.status == .unableToAssess)
        #expect(result.score == nil)
        #expect(result.action == .scanAgain)
        #expect(result.unavailableData.contains("Engine RPM"))
        #expect(result.unavailableData.contains("Control-module voltage"))
        #expect(result.unavailableData.contains("Fuel-system status"))
    }

    @Test
    func completeHealthyDataDoesNotPromisePerfectHealth() {
        let result = engine.assess(scan: completeScan(), vehicleID: UUID())

        #expect(result.status == .good)
        #expect(result.score == 92)
        #expect(result.action == .noImmediateAction)
        #expect(result.whyItMatters.contains("not a guarantee"))
    }

    private func completeScan(
        codes: [DiagnosticTroubleCode] = []
    ) -> NormalizedScan {
        NormalizedScan(
            values: completeValues,
            troubleCodes: codes,
            troubleCodesAvailable: true,
            fuelSystemStatus: "Closed loop",
            freezeFrameAvailable: !codes.isEmpty
        )
    }

    private var completeValues: [SensorMetric: Double] {
        [
            .engineRPM: 750,
            .vehicleSpeed: 0,
            .coolantTemperature: 90,
            .calculatedEngineLoad: 22,
            .throttlePosition: 16,
            .shortTermFuelTrim: 2,
            .longTermFuelTrim: 4,
            .controlModuleVoltage: 14.1
        ]
    }
}
