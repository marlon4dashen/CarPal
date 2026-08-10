import Foundation

enum AdapterConnectionState: Equatable, Sendable {
    case notChecked
    case disconnected
    case searching
    case connected(name: String)
}

enum AssessmentStatus: String, Equatable, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case attentionRecommended = "Attention recommended"
    case serviceSoon = "Service soon"
    case urgentWarning = "Urgent warning"
    case unableToAssess = "Unable to assess"
}

struct AssessmentPreview: Equatable, Sendable {
    let status: AssessmentStatus
    let score: Int?
    let completeness: Double
    let scannedAt: Date
    let nextAction: String
}

extension AssessmentPreview {
    static let sample = AssessmentPreview(
        status: .good,
        score: 86,
        completeness: 0.91,
        scannedAt: .now.addingTimeInterval(-7_200),
        nextAction: "No immediate action required"
    )
}
