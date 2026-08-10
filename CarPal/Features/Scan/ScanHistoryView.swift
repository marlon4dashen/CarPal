import SwiftUI

struct ScanHistoryView: View {
    let results: [ScanResult]
    let onSelect: (UUID) -> Void

    var body: some View {
        ZStack {
            CarPalCanvas()

            if results.isEmpty {
                ContentUnavailableView(
                    "No scan history",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed scans will be saved here on this device.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: CarPalSpacing.small) {
                        ForEach(results) { result in
                            Button { onSelect(result.id) } label: {
                                historyRow(result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(CarPalSpacing.medium)
                }
            }
        }
        .foregroundStyle(CarPalColor.ink)
        .navigationTitle("Scan History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyRow(_ result: ScanResult) -> some View {
        CarPalCard {
            HStack(alignment: .top, spacing: CarPalSpacing.medium) {
                Image(systemName: result.isAssessed ? "waveform.path.ecg" : "questionmark.diamond.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint(for: result.status))
                    .frame(width: 42, height: 42)
                    .background(tint(for: result.status).opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.status.rawValue)
                        .font(.carPalBody.weight(.bold))
                    Text(result.scannedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(CarPalColor.secondaryInk)
                    Text(result.findings.first?.title ?? result.blockingReason ?? result.summary)
                        .font(.subheadline)
                        .lineLimit(2)
                    Text(result.completeness, format: .percent.precision(.fractionLength(0)))
                        .font(.carPalEyebrow)
                        .foregroundStyle(CarPalColor.secondaryInk)
                }

                Spacer()
                if let score = result.score {
                    Text(score, format: .number)
                        .font(.carPalMetric)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CarPalColor.secondaryInk)
            }
        }
    }

    private func tint(for status: AssessmentStatus) -> Color {
        switch status {
        case .excellent, .good: CarPalColor.petrol
        case .attentionRecommended, .serviceSoon, .unableToAssess: CarPalColor.warning
        case .urgentWarning: CarPalColor.danger
        }
    }
}
