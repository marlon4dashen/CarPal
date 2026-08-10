import SwiftUI

struct VehicleHomeView: View {
    let vehicle: VehicleDraft
    let adapterState: AdapterConnectionState
    let assessment: AssessmentPreview?
    let onCheckAdapter: () -> Void
    let onScan: () -> Void
    let onEdit: () -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    private var adapter: AdapterStatusPresentation {
        AdapterStatusPresentation(state: adapterState)
    }

    private var latestAssessment: VehicleHomeAssessmentPresentation {
        VehicleHomeAssessmentPresentation(assessment: assessment)
    }

    var body: some View {
        ZStack {
            CarPalCanvas()

            ScrollView {
                LazyVStack(spacing: CarPalSpacing.medium) {
                    VehicleHeroView(vehicle: vehicle)
                    vehicleIdentity
                    adapterCard
                    assessmentCard
                    actions
                }
                .padding(.horizontal, CarPalSpacing.medium)
                .padding(.top, CarPalSpacing.small)
                .padding(.bottom, CarPalSpacing.xLarge)
            }
        }
        .foregroundStyle(CarPalColor.ink)
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(CarPalColor.ink)
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var vehicleIdentity: some View {
        CarPalCard {
            HStack(alignment: .top, spacing: CarPalSpacing.medium) {
                VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                    Text(vehicleDescription)
                        .font(.carPalSection)

                    Text(vehicleDetails)
                        .font(.carPalBody)
                        .foregroundStyle(CarPalColor.secondaryInk)
                }

                Spacer(minLength: CarPalSpacing.small)

                Button("Edit", action: onEdit)
                    .font(.carPalBody.weight(.bold))
                    .foregroundStyle(CarPalColor.accent)
                    .accessibilityLabel("Edit \(vehicle.nickname)")
            }

            Divider()
                .padding(.vertical, CarPalSpacing.small)

            HStack(spacing: CarPalSpacing.medium) {
                CarPalMetric(
                    label: "Mileage",
                    value: formattedMileage,
                    systemImage: "gauge.with.dots.needle.33percent"
                )
                CarPalMetric(
                    label: "Fuel",
                    value: vehicle.fuelType.isEmpty ? "Not set" : vehicle.fuelType,
                    systemImage: "fuelpump.fill"
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var adapterCard: some View {
        CarPalCard {
            HStack(spacing: CarPalSpacing.medium) {
                Image(systemName: adapter.systemImage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color(for: adapter.tone))
                    .frame(width: 45, height: 45)
                    .background(color(for: adapter.tone).opacity(0.11))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(adapter.title)
                        .font(.carPalBody.weight(.bold))
                    Text(adapter.detail)
                        .font(.carPalBody)
                        .foregroundStyle(CarPalColor.secondaryInk)
                }

                Spacer(minLength: CarPalSpacing.small)

                if adapterState == .searching {
                    ProgressView()
                        .tint(CarPalColor.warning)
                        .accessibilityLabel("Checking adapter connection")
                } else if let actionTitle = adapter.actionTitle {
                    Button(actionTitle, action: onCheckAdapter)
                        .font(.carPalBody.weight(.bold))
                        .foregroundStyle(CarPalColor.accent)
                        .buttonStyle(.plain)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var assessmentCard: some View {
        CarPalCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                    Text("LATEST VEHICLE HEALTH")
                        .font(.carPalEyebrow)
                        .foregroundStyle(CarPalColor.secondaryInk)

                    Text(latestAssessment.status)
                        .font(.carPalSection)
                        .foregroundStyle(color(for: latestAssessment.tone))
                }

                Spacer(minLength: CarPalSpacing.medium)

                scoreView
            }

            Divider()
                .padding(.vertical, CarPalSpacing.small)

            HStack(spacing: CarPalSpacing.medium) {
                CarPalMetric(
                    label: "Data complete",
                    value: latestAssessment.completeness,
                    systemImage: "chart.bar.fill"
                )
                CarPalMetric(
                    label: "Last scan",
                    value: latestAssessment.scanTime,
                    systemImage: "clock.fill"
                )
            }

            VStack(alignment: .leading, spacing: CarPalSpacing.xSmall) {
                Text("NEXT ACTION")
                    .font(.carPalEyebrow)
                    .foregroundStyle(CarPalColor.secondaryInk)

                Label(latestAssessment.nextAction, systemImage: nextActionIcon)
                    .font(.carPalBody.weight(.bold))
                    .foregroundStyle(CarPalColor.ink)
            }
            .padding(.top, CarPalSpacing.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(assessmentAccessibilityLabel)
    }

    @ViewBuilder
    private var scoreView: some View {
        if let score = latestAssessment.score {
            VStack(spacing: 0) {
                Text(score, format: .number)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                Text("OUT OF 100")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(CarPalColor.secondaryInk)
            }
            .accessibilityLabel("Health score \(score) out of 100")
        } else {
            Image(systemName: latestAssessment.kind == .unableToAssess ? "questionmark.diamond.fill" : "waveform.path.ecg")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(color(for: latestAssessment.tone))
                .accessibilityHidden(true)
        }
    }

    private var actions: some View {
        VStack(spacing: CarPalSpacing.small) {
            Button(action: onScan) {
                Label(scanButtonTitle, systemImage: "waveform.path.ecg.rectangle")
            }
            .buttonStyle(CarPalPrimaryButtonStyle())
            .disabled(adapterState == .searching)
            .accessibilityHint("Starts the guided vehicle scan")

            Button(action: onHistory) {
                Label("View scan history", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(CarPalQuietButtonStyle())
        }
    }

    private var vehicleDescription: String {
        [vehicle.modelYear, vehicle.make, vehicle.variant]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var vehicleDetails: String {
        [vehicle.trim, vehicle.colour]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    private var formattedMileage: String {
        guard let value = Int(vehicle.mileage) else {
            return vehicle.mileage.isEmpty ? "Not set" : "\(vehicle.mileage) km"
        }

        return value.formatted(.number.grouping(.automatic)) + " km"
    }

    private var scanButtonTitle: String {
        latestAssessment.kind == .noAssessment ? "Start first scan" : "Scan vehicle"
    }

    private var nextActionIcon: String {
        switch latestAssessment.kind {
        case .noAssessment:
            "play.circle.fill"
        case .scored:
            "arrow.right.circle.fill"
        case .unableToAssess:
            "arrow.clockwise.circle.fill"
        }
    }

    private var assessmentAccessibilityLabel: String {
        let score = latestAssessment.score.map { " Score \($0) out of 100." } ?? ""
        return """
        Latest vehicle health: \(latestAssessment.status).\(score) \
        Data completeness \(latestAssessment.completeness). \
        Last scan \(latestAssessment.scanTime). \
        Next action: \(latestAssessment.nextAction).
        """
    }

    private func color(for tone: VehicleHomeTone) -> Color {
        switch tone {
        case .positive:
            CarPalColor.petrol
        case .caution:
            CarPalColor.warning
        case .critical:
            CarPalColor.danger
        case .neutral:
            CarPalColor.secondaryInk
        }
    }
}

struct VehicleHomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(
                adapterState: .connected(name: "Veepeak OBDCheck BLE"),
                assessment: .sample
            )
            .previewDisplayName("Scored")

            preview(
                adapterState: .disconnected,
                assessment: nil
            )
            .previewDisplayName("No assessment")

            preview(
                adapterState: .searching,
                assessment: AssessmentPreview(
                    status: .unableToAssess,
                    score: nil,
                    completeness: 0.54,
                    scannedAt: .now.addingTimeInterval(-600),
                    nextAction: "Scan again with the engine running"
                )
            )
            .previewDisplayName("Unable to assess")
        }
    }

    private static func preview(
        adapterState: AdapterConnectionState,
        assessment: AssessmentPreview?
    ) -> some View {
        NavigationStack {
            VehicleHomeView(
                vehicle: .lexusNXPreview,
                adapterState: adapterState,
                assessment: assessment,
                onCheckAdapter: {},
                onScan: {},
                onEdit: {},
                onHistory: {},
                onSettings: {}
            )
        }
    }
}
