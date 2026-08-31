import SwiftUI

struct TroubleCodesView: View {
    @State private var model: TroubleCodesToolModel

    init(reader: any TroubleCodeReading) {
        _model = State(initialValue: TroubleCodesToolModel(reader: reader))
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
        .navigationTitle("Trouble Codes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.state.isLoading)
                .accessibilityLabel("Refresh trouble codes")
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
                ProgressView()
                    .tint(CarPalColor.accent)
                VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                    Text("Reading vehicle ECUs")
                        .font(.carPalBody.weight(.bold))
                    Text("Checking confirmed, pending, and permanent code states.")
                        .font(.carPalBody)
                        .foregroundStyle(CarPalColor.secondaryInk)
                }
            }
        }
    }

    @ViewBuilder
    private func reportContent(_ report: TroubleCodeReport) -> some View {
        CarPalCard {
            Label(
                report.totalCount == 0 ? "No trouble codes reported" : "\(report.totalCount) code states reported",
                systemImage: report.totalCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.carPalSection)
            .foregroundStyle(report.totalCount == 0 ? CarPalColor.petrol : CarPalColor.warning)

            Text("This is a current OBD reading. A clear result does not rule out every mechanical issue.")
                .font(.carPalBody)
                .foregroundStyle(CarPalColor.secondaryInk)
                .padding(.top, CarPalSpacing.small)
        }

        ForEach(DiagnosticCodeState.allCases) { state in
            codeSection(state: state, codes: report.codes(for: state))
        }
    }

    private func codeSection(
        state: DiagnosticCodeState,
        codes: [DiagnosticTroubleCode]
    ) -> some View {
        CarPalCard {
            HStack {
                Text(state.title.uppercased())
                    .font(.carPalEyebrow)
                    .foregroundStyle(CarPalColor.secondaryInk)
                Spacer()
                Text(codes.count, format: .number)
                    .font(.carPalBody.weight(.bold))
            }

            if codes.isEmpty {
                Text("None reported")
                    .font(.carPalBody)
                    .foregroundStyle(CarPalColor.secondaryInk)
                    .padding(.top, CarPalSpacing.small)
            } else {
                ForEach(Array(codes.enumerated()), id: \.offset) { index, code in
                    if index > 0 { Divider().padding(.vertical, CarPalSpacing.small) }
                    VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                        Text(code.code)
                            .font(.carPalMetric)
                            .foregroundStyle(CarPalColor.accent)
                        Text(code.summary)
                            .font(.carPalBody.weight(.semibold))
                        Text(evidenceDetail(for: state))
                            .font(.caption)
                            .foregroundStyle(CarPalColor.secondaryInk)
                    }
                    .padding(.top, index == 0 ? CarPalSpacing.small : 0)
                }
            }
        }
    }

    private func evidenceDetail(for state: DiagnosticCodeState) -> String {
        switch state {
        case .confirmed: "Stored by the vehicle after its fault criteria were met."
        case .pending: "Observed, but the vehicle may require another trip before confirming it."
        case .permanent: "Retained by the vehicle until its own verification criteria pass."
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
