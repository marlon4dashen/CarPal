import Foundation

struct ScanNormalizer: Sendable {
    func normalize(_ raw: RawScanData) -> NormalizedScan {
        NormalizedScan(
            values: raw.values,
            troubleCodes: raw.troubleCodes,
            troubleCodesAvailable: raw.troubleCodesAvailable,
            fuelSystemStatus: raw.fuelSystemStatus,
            freezeFrameAvailable: raw.freezeFrameAvailable
        )
    }
}

struct HealthAssessmentEngine: Sendable {
    func assess(scan: NormalizedScan, vehicleID: UUID, at date: Date = .now) -> ScanResult {
        let unavailable = minimumDataMissing(from: scan)
        guard unavailable.isEmpty else {
            return ScanResult(
                id: UUID(),
                vehicleID: vehicleID,
                scannedAt: date,
                status: .unableToAssess,
                score: nil,
                completeness: scan.completeness,
                summary: "The scan completed, but there is not enough reliable data to score your vehicle.",
                whyItMatters: "Missing readings are not proof of a vehicle problem. They only limit what CarPal can conclude.",
                action: .scanAgain,
                findings: [],
                unavailableData: unavailable,
                technicalSummary: technicalSummary(for: scan),
                blockingReason: "Required engine-state readings were unavailable."
            )
        }

        if let coolant = scan.values[.coolantTemperature], coolant >= 115 {
            let finding = AssessmentFinding(
                title: "Engine temperature is unusually high",
                detail: "Coolant temperature was (coolant.formatted(.number.precision(.fractionLength(0)))) C.",
                whyItMatters: "Continued overheating can cause serious engine damage.",
                severity: .urgent,
                technicalDetail: "ECT: (coolant) C"
            )
            return assessedResult(
                vehicleID: vehicleID,
                date: date,
                scan: scan,
                status: .urgentWarning,
                score: 28,
                summary: "The engine temperature needs immediate attention.",
                why: finding.whyItMatters,
                action: .stopDrivingWhenSafe,
                findings: [finding]
            )
        }

        if let code = scan.troubleCodes.first {
            let finding = AssessmentFinding(
                title: "Engine diagnostic code detected",
                detail: "The vehicle reported \(code.code): \(code.summary).",
                whyItMatters: "The cause should be diagnosed before it develops into drivability or fuel-use problems.",
                severity: .attention,
                technicalDetail: "Stored DTC \(code.code); freeze frame \(scan.freezeFrameAvailable ? "available" : "unavailable")"
            )
            return assessedResult(
                vehicleID: vehicleID,
                date: date,
                scan: scan,
                status: .serviceSoon,
                score: 68,
                summary: "Your vehicle can be assessed, but it reported an engine diagnostic code.",
                why: finding.whyItMatters,
                action: .arrangeDiagnosticInspection,
                findings: [finding]
            )
        }

        let finding = AssessmentFinding(
            title: "No immediate issue detected",
            detail: "Core readings were available and no diagnostic trouble codes were reported.",
            whyItMatters: "This scan found no immediate warning in the standard OBD-II data checked.",
            severity: .information,
            technicalDetail: technicalSummary(for: scan)
        )
        return assessedResult(
            vehicleID: vehicleID,
            date: date,
            scan: scan,
            status: .good,
            score: 92,
            summary: "The checked standard readings look normal right now.",
            why: "A good result is not a guarantee of overall mechanical condition or safety.",
            action: .noImmediateAction,
            findings: [finding]
        )
    }

    private func minimumDataMissing(from scan: NormalizedScan) -> [String] {
        var missing: [String] = []
        if !scan.troubleCodesAvailable { missing.append("Diagnostic trouble codes") }
        if scan.values[.engineRPM] == nil { missing.append("Engine RPM") }
        if scan.values[.coolantTemperature] == nil { missing.append("Coolant temperature") }
        if scan.values[.controlModuleVoltage] == nil { missing.append("Control-module voltage") }
        if scan.fuelSystemStatus == nil { missing.append("Fuel-system status") }
        return missing
    }

    private func assessedResult(
        vehicleID: UUID,
        date: Date,
        scan: NormalizedScan,
        status: AssessmentStatus,
        score: Int,
        summary: String,
        why: String,
        action: AssessmentAction,
        findings: [AssessmentFinding]
    ) -> ScanResult {
        ScanResult(
            id: UUID(),
            vehicleID: vehicleID,
            scannedAt: date,
            status: status,
            score: score,
            completeness: scan.completeness,
            summary: summary,
            whyItMatters: why,
            action: action,
            findings: findings,
            unavailableData: [],
            technicalSummary: technicalSummary(for: scan),
            blockingReason: nil
        )
    }

    private func technicalSummary(for scan: NormalizedScan) -> String {
        let readings = SensorMetric.allCases.compactMap { metric -> String? in
            guard let value = scan.values[metric] else { return nil }
            return "\(metric.rawValue): \(value)"
        }
        return readings.joined(separator: "\n")
    }
}
