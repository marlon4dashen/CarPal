import SwiftUI

struct ReadinessView: View {
    @State private var model: ReadinessToolModel

    init(reader: any ReadinessReading) {
        _model = State(initialValue: ReadinessToolModel(reader: reader))
    }

    var body: some View {
        ZStack {
            CarPalCanvas()
            ScrollView {
                VStack(spacing: CarPalSpacing.medium) {
                    content
                }
                .padding(CarPalSpacing.medium)
            }
        }
        .foregroundStyle(CarPalColor.ink)
        .navigationTitle("Emissions Readiness")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.state.isLoading)
                .accessibilityLabel("Refresh emissions readiness")
            }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            loadingCard
        case let .loaded(report):
            reportContent(report)
        case let .failed(failure):
            failureCard(failure)
        }
    }

    private var loadingCard: some View {
        CarPalCard {
            HStack(spacing: CarPalSpacing.medium) {
                ProgressView().tint(CarPalColor.accent)
                VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                    Text("Checking readiness monitors")
                        .font(.carPalBody.weight(.bold))
                    Text("Reading the vehicle's current emissions self-check status.")
                        .font(.carPalBody)
                        .foregroundStyle(CarPalColor.secondaryInk)
                }
            }
        }
    }

    @ViewBuilder
    private func reportContent(_ report: ReadinessReport) -> some View {
        CarPalCard {
            HStack(alignment: .top, spacing: CarPalSpacing.medium) {
                Image(systemName: report.isMILOn ? "engine.combustion.fill" : "checkmark.circle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(report.isMILOn ? CarPalColor.warning : CarPalColor.petrol)
                VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                    Text(report.isMILOn ? "Check-engine light is on" : "Check-engine light is off")
                        .font(.carPalSection)
                    Text("\(report.confirmedDTCCount) confirmed trouble code\(report.confirmedDTCCount == 1 ? "" : "s") reported")
                        .font(.carPalBody)
                        .foregroundStyle(CarPalColor.secondaryInk)
                }
            }
        }

        CarPalCard {
            Text("READINESS SUMMARY")
                .font(.carPalEyebrow)
                .foregroundStyle(CarPalColor.secondaryInk)
            Text("\(report.completedMonitorCount) of \(report.monitors.count) supported monitors complete")
                .font(.carPalSection)
                .padding(.top, CarPalSpacing.xSmall)
            Text(report.ignitionType.rawValue)
                .font(.carPalBody)
                .foregroundStyle(CarPalColor.secondaryInk)
                .padding(.top, 2)
        }

        CarPalCard {
            Text("SUPPORTED MONITORS")
                .font(.carPalEyebrow)
                .foregroundStyle(CarPalColor.secondaryInk)

            ForEach(Array(report.monitors.enumerated()), id: \.element.id) { index, monitor in
                if index > 0 { Divider() }
                HStack(spacing: CarPalSpacing.small) {
                    Image(systemName: monitor.isComplete ? "checkmark.circle.fill" : "clock.fill")
                        .foregroundStyle(monitor.isComplete ? CarPalColor.petrol : CarPalColor.warning)
                    Text(monitor.name)
                        .font(.carPalBody.weight(.semibold))
                    Spacer()
                    Text(monitor.isComplete ? "Complete" : "Not ready")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(monitor.isComplete ? CarPalColor.petrol : CarPalColor.warning)
                }
                .padding(.vertical, CarPalSpacing.small)
            }

            Text("Readiness is an emissions self-check status, not a complete vehicle health assessment.")
                .font(.caption)
                .foregroundStyle(CarPalColor.secondaryInk)
                .padding(.top, CarPalSpacing.small)
        }
    }

    private func failureCard(_ failure: DiagnosticToolFailure) -> some View {
        CarPalCard {
            Label(failure.title, systemImage: "exclamationmark.triangle.fill")
                .font(.carPalSection)
                .foregroundStyle(CarPalColor.warning)
            Text(failure.guidance)
                .font(.carPalBody)
                .foregroundStyle(CarPalColor.secondaryInk)
                .padding(.top, CarPalSpacing.small)
            Button("Try again") {
                Task { await model.load() }
            }
            .buttonStyle(CarPalPrimaryButtonStyle())
            .padding(.top, CarPalSpacing.medium)
        }
    }
}
