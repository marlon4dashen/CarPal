import SwiftUI

struct ScanResultView: View {
    let result: ScanResult
    let onPrimaryAction: () -> Void
    let onHome: () -> Void

    @State private var showsTechnicalDetails = false

    var body: some View {
        ZStack {
            CarPalCanvas()
            ScrollView {
                VStack(spacing: CarPalSpacing.medium) {
                    resultHero
                    explanationCard
                    findingsCard
                    completenessCard
                    technicalCard
                    actions
                }
                .padding(.horizontal, CarPalSpacing.medium)
                .padding(.vertical, CarPalSpacing.small)
            }
        }
        .foregroundStyle(CarPalColor.ink)
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    private var resultHero: some View {
        VStack(alignment: .leading, spacing: CarPalSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.isAssessed ? "VEHICLE HEALTH" : "SCAN OUTCOME")
                        .font(.carPalEyebrow)
                        .foregroundStyle(.white.opacity(0.72))
                    Text(result.status.rawValue)
                        .font(.carPalTitle)
                        .foregroundStyle(.white)
                }
                Spacer()
                if let score = result.score {
                    VStack(spacing: 0) {
                        Text(score, format: .number)
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                        Text("OUT OF 100")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                } else {
                    Image(systemName: "questionmark.diamond.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Divider().overlay(.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT ACTION")
                    .font(.carPalEyebrow)
                    .foregroundStyle(.white.opacity(0.72))
                Text(result.action.title)
                    .font(.carPalSection)
                    .foregroundStyle(.white)
            }

            Text(result.scannedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(CarPalSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroColor.gradient)
        .clipShape(RoundedRectangle(cornerRadius: CarPalRadius.hero, style: .continuous))
    }

    private var explanationCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: CarPalSpacing.small) {
                Text(result.summary)
                    .font(.carPalSection)
                if let blockingReason = result.blockingReason {
                    Label(blockingReason, systemImage: "exclamationmark.triangle.fill")
                        .font(.carPalBody.weight(.semibold))
                        .foregroundStyle(CarPalColor.warning)
                }
                Text(result.whyItMatters)
                    .font(.carPalBody)
                    .foregroundStyle(CarPalColor.secondaryInk)
            }
        }
    }

    @ViewBuilder
    private var findingsCard: some View {
        if !result.findings.isEmpty {
            CarPalCard {
                VStack(alignment: .leading, spacing: CarPalSpacing.medium) {
                    Text("TOP FINDINGS")
                        .font(.carPalEyebrow)
                        .foregroundStyle(CarPalColor.secondaryInk)
                    ForEach(result.findings) { finding in
                        VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                            Label(finding.title, systemImage: icon(for: finding.severity))
                                .font(.carPalBody.weight(.bold))
                                .foregroundStyle(color(for: finding.severity))
                            Text(finding.detail)
                                .font(.carPalBody)
                            Text(finding.whyItMatters)
                                .font(.subheadline)
                                .foregroundStyle(CarPalColor.secondaryInk)
                        }
                    }
                }
            }
        }
    }

    private var completenessCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: CarPalSpacing.small) {
                HStack {
                    CarPalMetric(
                        label: "Data complete",
                        value: result.completeness.formatted(.percent.precision(.fractionLength(0))),
                        systemImage: "chart.bar.fill"
                    )
                    CarPalMetric(
                        label: "Confidence",
                        value: confidenceLabel,
                        systemImage: "checkmark.shield.fill"
                    )
                }
                if !result.unavailableData.isEmpty {
                    Divider()
                    Text("UNAVAILABLE DATA")
                        .font(.carPalEyebrow)
                        .foregroundStyle(CarPalColor.secondaryInk)
                    Text(result.unavailableData.joined(separator: ", "))
                        .font(.carPalBody)
                    Text("Unavailable data does not itself indicate a vehicle fault.")
                        .font(.subheadline)
                        .foregroundStyle(CarPalColor.secondaryInk)
                }
            }
        }
    }

    private var technicalCard: some View {
        CarPalCard {
            DisclosureGroup("Technical details", isExpanded: $showsTechnicalDetails) {
                VStack(alignment: .leading, spacing: CarPalSpacing.small) {
                    ForEach(result.findings) { finding in
                        Text(finding.technicalDetail)
                    }
                    Text(result.technicalSummary)
                }
                .font(.caption.monospaced())
                .foregroundStyle(CarPalColor.secondaryInk)
                .padding(.top, CarPalSpacing.small)
            }
            .font(.carPalBody.weight(.bold))
            .tint(CarPalColor.accent)
        }
    }

    private var actions: some View {
        VStack(spacing: CarPalSpacing.small) {
            Button(result.action.title, action: onPrimaryAction)
                .buttonStyle(CarPalPrimaryButtonStyle())
            Button("Return to vehicle", action: onHome)
                .buttonStyle(CarPalQuietButtonStyle())
        }
    }

    private var confidenceLabel: String {
        if !result.isAssessed { return "Limited" }
        return result.completeness >= 0.9 ? "High" : "Moderate"
    }

    private var heroColor: Color {
        switch result.status {
        case .excellent, .good: CarPalColor.petrol
        case .attentionRecommended, .serviceSoon, .unableToAssess: CarPalColor.warning
        case .urgentWarning: CarPalColor.danger
        }
    }

    private func icon(for severity: FindingSeverity) -> String {
        switch severity {
        case .information: "checkmark.circle.fill"
        case .attention: "exclamationmark.circle.fill"
        case .urgent: "exclamationmark.octagon.fill"
        }
    }

    private func color(for severity: FindingSeverity) -> Color {
        switch severity {
        case .information: CarPalColor.petrol
        case .attention: CarPalColor.warning
        case .urgent: CarPalColor.danger
        }
    }
}
