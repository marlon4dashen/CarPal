import SwiftUI

struct VehicleRegistrationView: View {
    @State private var coordinator: VehicleRegistrationCoordinator
    private let selectionPolicy = VehicleRegistrationSelectionPolicy()

    init(
        store: VehicleProfileStore,
        integration: VehicleIntegration,
        backendClient: any VehicleIdentificationClient
    ) {
        _coordinator = State(initialValue: VehicleRegistrationCoordinator(
            sessionManager: integration.sessionManager,
            identityReader: integration.identityReader,
            backendClient: backendClient,
            store: store
        ))
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        ZStack {
            CarPalCanvas()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    progressStrip
                    phaseContent(coordinator: coordinator)
                    if let message = coordinator.errorMessage {
                        errorCard(message)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Register vehicle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(CarPalColor.petrol)
                    .frame(width: 64, height: 64)
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Let the vehicle introduce itself.")
                .font(.carPalTitle)
                .foregroundStyle(CarPalColor.ink)
            Text("CarPal reads the VIN through your Veepeak adapter, then asks you to confirm what the vehicle reports.")
                .font(.carPalBody)
                .foregroundStyle(CarPalColor.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressStrip: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index <= progressIndex ? CarPalColor.accent : CarPalColor.hairline)
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("Registration step \(progressIndex + 1) of 4")
    }

    @ViewBuilder
    private func phaseContent(coordinator: VehicleRegistrationCoordinator) -> some View {
        switch coordinator.phase {
        case .needsAdapter:
            adapterCard
        case .connecting, .readingIdentity, .decoding, .saving:
            workingCard
        case .needsVINRecovery:
            vinRecoveryCard(coordinator: coordinator)
        case .needsModelYear:
            yearCard(coordinator: coordinator)
        case .confirming:
            confirmationCard(coordinator: coordinator)
        case .registered:
            EmptyView()
        }
    }

    private var adapterCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Connect before registration", systemImage: "car.badge.gearshape")
                    .font(.carPalSection)
                    .foregroundStyle(CarPalColor.ink)
                Text("Plug the adapter into the vehicle, turn the ignition on, and stay nearby. Manual VIN entry cannot bypass this check.")
                    .font(.carPalBody)
                    .foregroundStyle(CarPalColor.secondaryInk)
                Button("Find adapter and read vehicle") {
                    Task { await coordinator.beginConnection() }
                }
                .buttonStyle(CarPalPrimaryButtonStyle())
            }
        }
    }

    private var workingCard: some View {
        CarPalCard {
            HStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(CarPalColor.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(workingTitle)
                        .font(.carPalSection)
                    Text(workingDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func vinRecoveryCard(
        coordinator: VehicleRegistrationCoordinator
    ) -> some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: 15) {
                Label("VIN was not available", systemImage: "text.viewfinder")
                    .font(.carPalSection)
                Text("The adapter session is ready, but this ECU did not return Mode 09 VIN data. Enter the VIN from the windshield or door label.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                registrationField("VIN", text: $coordinator.draft.vin, capitalization: .characters)
                Button("Use this VIN") { coordinator.acceptRecoveredVIN() }
                    .buttonStyle(CarPalPrimaryButtonStyle())
                    .disabled(coordinator.draft.vin.count != 17)
            }
        }
    }

    private func yearCard(coordinator: VehicleRegistrationCoordinator) -> some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Confirm model year", systemImage: "calendar")
                    .font(.carPalSection)
                sourceRow(label: "VIN", value: coordinator.draft.vin, source: vinSource)
                Picker("Model year", selection: $coordinator.draft.modelYear) {
                    Text("Select year").tag("")
                    ForEach(modelYears, id: \.self) { year in
                        Text(String(year)).tag(String(year))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, 12)
                .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 13))
                Text("Model year is required by the VIN decoder and remains user-confirmed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Decode vehicle") {
                    Task { await coordinator.decodeVehicle() }
                }
                .buttonStyle(CarPalPrimaryButtonStyle())
                .disabled(!coordinator.draft.canDecode)
            }
        }
    }

    private func confirmationCard(
        coordinator: VehicleRegistrationCoordinator
    ) -> some View {
        VStack(spacing: 18) {
            if !coordinator.decodeWarnings.isEmpty {
                CarPalCard {
                    Label("Decoder notes", systemImage: "exclamationmark.triangle")
                        .font(.carPalSection)
                    ForEach(coordinator.decodeWarnings, id: \.self) { warning in
                        Text(warning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 7)
                    }
                }
            }

            CarPalCard {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Confirm your vehicle")
                        .font(.carPalSection)
                    Text("Review the decoded identity, then choose only from compatible vehicle options. Use Change VIN or model year to correct identity data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    registrationField("Nickname", text: $coordinator.draft.nickname)
                    readOnlyRegistrationField("Make", value: coordinator.draft.make, source: source(\.make))
                    readOnlyRegistrationField("Model", value: coordinator.draft.model, source: source(\.model))
                    readOnlyRegistrationField("Model year", value: coordinator.draft.modelYear, source: source(\.modelYear))
                    readOnlyRegistrationField("Engine", value: coordinator.draft.engineModel, source: source(\.engineModel))
                    readOnlyRegistrationField("Fuel type", value: coordinator.draft.fuelType, source: source(\.fuelTypePrimary))
                    readOnlyRegistrationField("Drive type", value: coordinator.draft.driveType, source: source(\.driveType))
                    readOnlyRegistrationField("Transmission", value: coordinator.draft.transmissionStyle, source: source(\.transmissionStyle))
                    selectionField(
                        trimIsCatalogMatched ? "Trim" : "Trim (unavailable)",
                        selection: $coordinator.draft.trim,
                        options: selectionPolicy.trimOptions(for: coordinator.draft),
                        emptyLabel: trimIsCatalogMatched ? "Select trim" : "No catalog match",
                        isDisabled: !trimIsCatalogMatched
                    )
                    selectionField(
                        trimIsCatalogMatched ? "Exterior colour" : "Exterior colour (optional)",
                        selection: $coordinator.draft.colour,
                        options: selectionPolicy.colourOptions(for: coordinator.draft),
                        emptyLabel: colourEmptyLabel,
                        isDisabled: colourSelectionIsDisabled
                    )
                    registrationField("Mileage (optional)", text: $coordinator.draft.mileage, keyboard: .decimalPad)
                }
                .onChange(of: coordinator.draft.trim) { _, _ in
                    let options = selectionPolicy.colourOptions(for: coordinator.draft)
                    if !coordinator.draft.colour.isEmpty,
                       !options.contains(coordinator.draft.colour) {
                        coordinator.draft.colour = ""
                    }
                }
            }

            eligibilityCard

            Button("Confirm and save vehicle") {
                Task { await coordinator.saveConfirmedVehicle() }
            }
            .buttonStyle(CarPalPrimaryButtonStyle())
            .disabled(!coordinator.canSaveConfirmedVehicle)

            Button("Change VIN or model year") { coordinator.changeVINOrYear() }
                .buttonStyle(CarPalQuietButtonStyle())
        }
    }

    private var eligibilityCard: some View {
        CarPalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Diagnostic compatibility")
                    .font(.carPalSection)
                compatibilityRow("Quick Scan", level: coordinator.eligibility?.quickScan)
                compatibilityRow("Health Scan", level: coordinator.eligibility?.healthScan)
                ForEach(coordinator.eligibility?.limitations ?? [], id: \.self) { limitation in
                    Text(limitation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func registrationField(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .words,
        source: APIAttributeSource? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let source {
                    Text(source.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(CarPalColor.petrol)
                }
            }
            TextField("Unknown", text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 13)
                .frame(minHeight: 47)
                .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func readOnlyRegistrationField(
        _ label: String,
        value: String,
        source: APIAttributeSource?
    ) -> some View {
        registrationLabel(label, source: source) {
            Text(value.isEmpty ? "Unknown" : value)
                .foregroundStyle(value.isEmpty ? .secondary : CarPalColor.ink)
                .frame(maxWidth: .infinity, minHeight: 47, alignment: .leading)
                .padding(.horizontal, 13)
                .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private func selectionField(
        _ label: String,
        selection: Binding<String>,
        options: [String],
        emptyLabel: String = "Not set",
        isDisabled: Bool = false,
        source: APIAttributeSource? = nil
    ) -> some View {
        registrationLabel(label, source: source) {
            Picker(label, selection: selection) {
                Text(emptyLabel).tag("")
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 47, alignment: .leading)
            .padding(.horizontal, 13)
            .background(.white.opacity(isDisabled ? 0.45 : 0.76), in: RoundedRectangle(cornerRadius: 13))
            .disabled(isDisabled)
        }
    }

    private func registrationLabel<Content: View>(
        _ label: String,
        source: APIAttributeSource?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline.weight(.semibold))
                Spacer()
                if let source {
                    Text(source.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(CarPalColor.petrol)
                }
            }
            content()
        }
    }

    private func sourceRow(
        label: String,
        value: String,
        source: APIAttributeSource
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased()).font(.carPalEyebrow).foregroundStyle(.secondary)
                Text(value).font(.body.monospaced())
            }
            Spacer()
            CarPalStatusPill(title: source.label, systemImage: "checkmark.seal", tint: CarPalColor.petrol)
        }
    }

    private func compatibilityRow(_ label: String, level: APISupportLevel?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(level?.label ?? "Checking")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(level == .supported ? CarPalColor.petrol : CarPalColor.warning)
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(CarPalColor.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(CarPalColor.danger.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
    }

    private var progressIndex: Int {
        switch coordinator.phase {
        case .needsAdapter, .connecting: 0
        case .readingIdentity, .needsVINRecovery: 1
        case .needsModelYear, .decoding: 2
        case .confirming, .saving, .registered: 3
        }
    }

    private var workingTitle: String {
        switch coordinator.phase {
        case .connecting: "Preparing adapter"
        case .readingIdentity: "Reading vehicle identity"
        case .decoding: "Decoding VIN"
        case .saving: "Saving confirmed profile"
        default: "Working"
        }
    }

    private var workingDetail: String {
        switch coordinator.phase {
        case .connecting: "Discovering Veepeak, connecting, and initializing ELM..."
        case .readingIdentity: "Requesting VIN and available ECU information through Mode 09..."
        case .decoding: "Asking the CarPal backend to normalize the vehicle identity..."
        case .saving: "Resolving final diagnostic eligibility before local save..."
        default: "Please keep the adapter connected."
        }
    }

    private var vinSource: APIAttributeSource {
        coordinator.obdIdentity?.vin == nil ? .user : .obd
    }

    private var modelYears: [Int] {
        Array((1981...(Calendar.current.component(.year, from: .now) + 1)).reversed())
    }

    private var colourSelectionIsDisabled: Bool {
        trimIsCatalogMatched && coordinator.draft.trim.isEmpty
    }

    private var colourEmptyLabel: String {
        colourSelectionIsDisabled ? "Select a trim first" : "Not set"
    }

    private var trimIsCatalogMatched: Bool {
        !selectionPolicy.trimOptions(for: coordinator.draft).isEmpty
    }

    private func source(
        _ keyPath: KeyPath<APIVehicleCandidate, APIVehicleAttribute<String>>
    ) -> APIAttributeSource? {
        coordinator.candidate?[keyPath: keyPath].source
    }

    private func source(
        _ keyPath: KeyPath<APIVehicleCandidate, APIVehicleAttribute<Int>>
    ) -> APIAttributeSource? {
        coordinator.candidate?[keyPath: keyPath].source
    }
}

private extension APIAttributeSource {
    var label: String {
        switch self {
        case .obd: "Vehicle"
        case .vinDecoder: "VIN decoded"
        case .oemDatabase: "OEM data"
        case .user: "User confirmed"
        }
    }
}

private extension APISupportLevel {
    var label: String {
        switch self {
        case .supported: "Supported"
        case .limited: "Limited"
        case .unsupported: "Unavailable"
        }
    }
}
