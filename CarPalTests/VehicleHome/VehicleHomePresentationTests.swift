import Foundation
import Testing
@testable import CarPal

struct VehicleHomePresentationTests {
    @Test
    func uncheckedAdapterOffersAnExplicitConnectionCheck() {
        let presentation = AdapterStatusPresentation(state: .notChecked)

        #expect(presentation.title == "Adapter not checked")
        #expect(presentation.actionTitle == "Check")
        #expect(presentation.tone == .neutral)
    }

    @Test
    func failedCheckIsDifferentFromNeverChecked() {
        let presentation = AdapterStatusPresentation(state: .disconnected)

        #expect(presentation.title == "Adapter not found")
        #expect(presentation.actionTitle == "Try again")
    }

    @Test
    func connectedAdapterIncludesItsNameAndPositiveTone() {
        let presentation = AdapterStatusPresentation(
            state: .connected(name: "Veepeak OBDCheck BLE")
        )

        #expect(presentation.title == "Adapter connected")
        #expect(presentation.detail == "Veepeak OBDCheck BLE")
        #expect(presentation.tone == .positive)
    }

    @Test
    func missingAssessmentPromptsFirstScanWithoutScore() {
        let presentation = VehicleHomeAssessmentPresentation(assessment: nil)

        #expect(presentation.kind == .noAssessment)
        #expect(presentation.score == nil)
        #expect(presentation.completeness == "Not available")
        #expect(presentation.scanTime == "Not scanned")
        #expect(presentation.nextAction == "Run your first vehicle scan")
    }

    @Test
    func scoredAssessmentKeepsScoreStatusAndActionTogether() {
        let assessment = AssessmentPreview(
            status: .serviceSoon,
            score: 63,
            completeness: 0.82,
            scannedAt: Date(timeIntervalSince1970: 1_700_000_000),
            nextAction: "Book an inspection this week"
        )

        let presentation = VehicleHomeAssessmentPresentation(
            assessment: assessment,
            now: Date(timeIntervalSince1970: 1_700_003_600)
        )

        #expect(presentation.kind == .scored)
        #expect(presentation.status == "Service soon")
        #expect(presentation.score == 63)
        #expect(presentation.completeness == "82%")
        #expect(presentation.nextAction == "Book an inspection this week")
        #expect(presentation.tone == .caution)
    }

    @Test
    func unableToAssessNeverDisplaysAnAccidentalScore() {
        let assessment = AssessmentPreview(
            status: .unableToAssess,
            score: 99,
            completeness: 0.48,
            scannedAt: Date(timeIntervalSince1970: 1_700_000_000),
            nextAction: "Scan again with the engine running"
        )

        let presentation = VehicleHomeAssessmentPresentation(assessment: assessment)

        #expect(presentation.kind == .unableToAssess)
        #expect(presentation.status == "Unable to assess")
        #expect(presentation.score == nil)
        #expect(presentation.completeness == "48%")
        #expect(presentation.tone == .caution)
    }

    @Test(
        "Assessment statuses map to conservative visual tones",
        arguments: [
            (AssessmentStatus.excellent, VehicleHomeTone.positive),
            (.good, .positive),
            (.attentionRecommended, .caution),
            (.serviceSoon, .caution),
            (.urgentWarning, .critical)
        ]
    )
    func statusTone(status: AssessmentStatus, expectedTone: VehicleHomeTone) {
        let assessment = AssessmentPreview(
            status: status,
            score: 75,
            completeness: 1,
            scannedAt: .now,
            nextAction: "Follow the recommended action"
        )

        #expect(
            VehicleHomeAssessmentPresentation(assessment: assessment).tone
                == expectedTone
        )
    }
}
