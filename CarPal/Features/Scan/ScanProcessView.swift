import SwiftUI
import UIKit

struct ScanProcessView: View {
    @Environment(\.dismiss) private var dismiss

    let vehicleID: UUID
    let onComplete: (ScanResult) throws -> Void

    @State private var coordinator: ScanCoordinator
    @State private var showsCancelConfirmation = false
    @State private var saveError: String?

    init(
        vehicleID: UUID,
        coordinator: ScanCoordinator,
        onComplete: @escaping (ScanResult) throws -> Void
    ) {
        self.vehicleID = vehicleID
        self.onComplete = onComplete
        _coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        ZStack {
            CarPalCanvas()

            ScrollView {
                VStack(alignment: .leading, spacing: CarPalSpacing.large) {
                    introduction
                    progressCard
                    stagesCard
                    safetyNote
                    cancelButton
                }
                .padding(.horizontal, CarPalSpacing.medium)
                .padding(.vertical, CarPalSpacing.small)
            }
        }
        .foregroundStyle(CarPalColor.ink)
        .navigationTitle("Vehicle Scan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(coordinator.isRunning)
        .task { await runScan() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if coordinator.isRunning {
                coordinator.cancel()
            }
        }
        .confirmationDialog(
            "Cancel this scan?",
            isPresented: $showsCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel scan", role: .destructive) { dismiss() }
            Button("Keep scanning", role: .cancel) {}
        } message: {
            Text("Vehicle data has already been collected. This unfinished scan will not be saved.")
        }
        .alert(
            "Could not save scan",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("Try again") { completeIfReady() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(saveError ?? "The result remains available until you leave this screen.")
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
            Text(coordinator.failure == nil ? "Scanning your vehicle" : "Scan needs attention")
                .font(.carPalTitle)
            Text("Keep the engine running and stay near the adapter.")
                .font(.carPalBody)
                .foregroundStyle(CarPalColor.secondaryInk)
        }
    }

    private var progressCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: CarPalSpacing.small) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeTitle)
                            .font(.carPalBody.weight(.bold))
                        Text(stepLabel)
                            .font(.carPalEyebrow)
                            .foregroundStyle(CarPalColor.secondaryInk)
                    }
                    Spacer()
                    Text(coordinator.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.carPalMetric)
                        .foregroundStyle(CarPalColor.petrol)
                }

                ProgressView(value: coordinator.progress)
                    .tint(CarPalColor.petrol)
                    .accessibilityLabel("Scan progress")
            }
        }
    }

    private var stagesCard: some View {
        CarPalCard {
            VStack(spacing: 0) {
                ForEach(Array(coordinator.stages.enumerated()), id: \.element.id) { index, snapshot in
                    ScanStageRow(snapshot: snapshot, isLast: index == coordinator.stages.count - 1) {
                        Task { await runScan() }
                    }
                }
            }
        }
    }

    private var safetyNote: some View {
        Label("Do not unplug the adapter during an active scan.", systemImage: "info.circle.fill")
            .font(.carPalBody.weight(.semibold))
            .foregroundStyle(CarPalColor.secondaryInk)
            .padding(.horizontal, CarPalSpacing.small)
    }

    private var cancelButton: some View {
        Button {
            if coordinator.hasCollectedData {
                showsCancelConfirmation = true
            } else {
                dismiss()
            }
        } label: {
            Text(coordinator.isRunning ? "Cancel scan" : "Back to vehicle")
        }
        .buttonStyle(CarPalQuietButtonStyle())
    }

    private var activeTitle: String {
        if let failure = coordinator.failure { return failure.stage.title }
        if let stage = coordinator.activeStage { return stage.title }
        return coordinator.result == nil ? "Preparing scan" : "Scan complete"
    }

    private var stepLabel: String {
        let stage = coordinator.activeStage ?? coordinator.failure?.stage
        guard let stage else { return coordinator.result == nil ? "Starting" : "7 of 7 steps" }
        return "Step \(stage.rawValue + 1) of \(ScanStage.allCases.count)"
    }

    private func runScan() async {
        guard !coordinator.isRunning else { return }
        await coordinator.begin(vehicleID: vehicleID)
        completeIfReady()
    }

    private func completeIfReady() {
        guard let result = coordinator.result else { return }
        do {
            try onComplete(result)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct ScanStageRow: View {
    let snapshot: ScanStageSnapshot
    let isLast: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: CarPalSpacing.small) {
            VStack(spacing: 0) {
                statusIcon
                    .frame(width: 28, height: 28)
                if !isLast {
                    Rectangle()
                        .fill(connectorColor)
                        .frame(width: 2)
                        .frame(minHeight: 37)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.stage.title)
                    .font(.carPalBody.weight(.bold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(detailColor)
                    .fixedSize(horizontal: false, vertical: true)

                if case let .failed(failure) = snapshot.state {
                    VStack(alignment: .leading, spacing: CarPalSpacing.small) {
                        Text(failure.guidance)
                            .font(.subheadline)
                        Text("Diagnostic code: \(failure.code.rawValue)")
                            .font(.caption.monospaced())
                            .foregroundStyle(CarPalColor.secondaryInk)
                        if failure.allowsRetry {
                            Button("Try again", action: onRetry)
                                .font(.carPalBody.weight(.bold))
                                .foregroundStyle(CarPalColor.accent)
                        }
                    }
                    .padding(.top, CarPalSpacing.xSmall)
                }
            }
            .padding(.bottom, isLast ? 0 : CarPalSpacing.small)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch snapshot.state {
        case .waiting:
            Image(systemName: "circle")
                .foregroundStyle(CarPalColor.secondaryInk.opacity(0.45))
        case .active:
            ProgressView()
                .tint(CarPalColor.petrol)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CarPalColor.petrol)
        case .limited:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(CarPalColor.warning)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(CarPalColor.danger)
        }
    }

    private var detail: String {
        switch snapshot.state {
        case .waiting: "Waiting"
        case .active: snapshot.stage.activeDetail
        case let .completed(detail), let .limited(detail): detail
        case let .failed(failure): failure.message
        }
    }

    private var detailColor: Color {
        switch snapshot.state {
        case .limited: CarPalColor.warning
        case .failed: CarPalColor.danger
        default: CarPalColor.secondaryInk
        }
    }

    private var connectorColor: Color {
        switch snapshot.state {
        case .completed, .limited: CarPalColor.petrol.opacity(0.35)
        default: CarPalColor.hairline
        }
    }
}
