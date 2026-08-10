import Foundation
import SwiftData

@Model
final class ScanHistoryEntity {
    @Attribute(.unique) var id: UUID
    var vehicleID: UUID
    var scannedAt: Date
    var statusRawValue: String
    var score: Int?
    var completeness: Double
    var summary: String
    var whyItMatters: String
    var actionRawValue: String
    var findingsData: Data
    var unavailableData: Data
    var technicalSummary: String
    var blockingReason: String?

    init(result: ScanResult) throws {
        id = result.id
        vehicleID = result.vehicleID
        scannedAt = result.scannedAt
        statusRawValue = result.status.rawValue
        score = result.score
        completeness = result.completeness
        summary = result.summary
        whyItMatters = result.whyItMatters
        actionRawValue = result.action.rawValue
        findingsData = try JSONEncoder().encode(result.findings)
        unavailableData = try JSONEncoder().encode(result.unavailableData)
        technicalSummary = result.technicalSummary
        blockingReason = result.blockingReason
    }

    var result: ScanResult? {
        guard let status = AssessmentStatus(rawValue: statusRawValue),
              let action = AssessmentAction(rawValue: actionRawValue),
              let findings = try? JSONDecoder().decode([AssessmentFinding].self, from: findingsData),
              let unavailable = try? JSONDecoder().decode([String].self, from: unavailableData) else {
            return nil
        }

        return ScanResult(
            id: id,
            vehicleID: vehicleID,
            scannedAt: scannedAt,
            status: status,
            score: score,
            completeness: completeness,
            summary: summary,
            whyItMatters: whyItMatters,
            action: action,
            findings: findings,
            unavailableData: unavailable,
            technicalSummary: technicalSummary,
            blockingReason: blockingReason
        )
    }
}
