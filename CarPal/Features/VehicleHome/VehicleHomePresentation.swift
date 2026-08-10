import Foundation

enum VehicleHomeTone: Equatable, Sendable {
    case positive
    case caution
    case critical
    case neutral
}

struct AdapterStatusPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let systemImage: String
    let tone: VehicleHomeTone
    let actionTitle: String?

    init(state: AdapterConnectionState) {
        switch state {
        case .notChecked:
            title = "Adapter not checked"
            detail = "Check the Veepeak connection before scanning"
            systemImage = "bolt.horizontal.circle"
            tone = .neutral
            actionTitle = "Check"
        case .disconnected:
            title = "Adapter not found"
            detail = "Confirm it is plugged in and nearby"
            systemImage = "bolt.horizontal.circle"
            tone = .neutral
            actionTitle = "Try again"
        case .searching:
            title = "Finding adapter"
            detail = "Looking for Veepeak OBDCheck BLE"
            systemImage = "antenna.radiowaves.left.and.right"
            tone = .caution
            actionTitle = nil
        case let .connected(name):
            title = "Adapter connected"
            detail = name
            systemImage = "checkmark.circle.fill"
            tone = .positive
            actionTitle = nil
        }
    }
}

enum AssessmentPresentationKind: Equatable, Sendable {
    case noAssessment
    case scored
    case unableToAssess
}

struct VehicleHomeAssessmentPresentation: Equatable, Sendable {
    let kind: AssessmentPresentationKind
    let status: String
    let score: Int?
    let completeness: String
    let scanTime: String
    let nextAction: String
    let tone: VehicleHomeTone

    init(assessment: AssessmentPreview?, now: Date = .now) {
        guard let assessment else {
            kind = .noAssessment
            status = "No scan yet"
            score = nil
            completeness = "Not available"
            scanTime = "Not scanned"
            nextAction = "Run your first vehicle scan"
            tone = .neutral
            return
        }

        completeness = assessment.completeness.formatted(
            .percent.precision(.fractionLength(0))
        )
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.dateTimeStyle = .named
        relativeFormatter.unitsStyle = .full
        scanTime = relativeFormatter.localizedString(
            for: assessment.scannedAt,
            relativeTo: now
        )
        nextAction = assessment.nextAction

        if assessment.status == .unableToAssess {
            kind = .unableToAssess
            status = assessment.status.rawValue
            score = nil
            tone = .caution
            return
        }

        kind = .scored
        status = assessment.status.rawValue
        score = assessment.score
        tone = Self.tone(for: assessment.status)
    }

    private static func tone(for status: AssessmentStatus) -> VehicleHomeTone {
        switch status {
        case .excellent, .good:
            .positive
        case .attentionRecommended, .serviceSoon:
            .caution
        case .urgentWarning:
            .critical
        case .unableToAssess:
            .neutral
        }
    }
}
