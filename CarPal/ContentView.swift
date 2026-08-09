import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var store: VehicleProfileStore?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let store {
                VehicleAppFlow(store: store)
            } else if let loadError {
                ContentUnavailableView(
                    "Vehicle data unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("Opening your garage...")
                    .task {
                        loadStore()
                    }
            }
        }
    }

    private func loadStore() {
        guard store == nil else {
            return
        }

        let store = VehicleProfileStore(modelContext: modelContext)

        do {
            try store.load()
#if DEBUG
            if DebugLaunchConfiguration.seedsPreviewVehicle {
                let previewDraft = DebugLaunchConfiguration.previewDraft
                if store.vehicle == nil {
                    try store.create(from: previewDraft)
                } else if DebugLaunchConfiguration.resetsPreviewVehicle {
                    try store.update(with: previewDraft)
                }
            }
#endif
            self.store = store
        } catch {
            loadError = "CarPal could not load the saved vehicle. \(error.localizedDescription)"
        }
    }
}

private struct VehicleAppFlow: View {
    @Bindable var store: VehicleProfileStore

    @State private var setupDraft = VehicleDraft()
    @State private var showsSetupValidationErrors = false
    @State private var presentedDestination: PlaceholderDestination?
    @State private var showsEditVehicle = false
    @State private var persistenceError: String?

    private let validator = VehicleDraftValidator()

    var body: some View {
        NavigationStack {
            if let vehicle = store.vehicle {
                VehicleHomeView(
                    vehicle: vehicle.draft,
                    adapterState: DebugLaunchConfiguration.adapterState,
                    assessment: DebugLaunchConfiguration.assessment,
                    onScan: { presentedDestination = .scan },
                    onEdit: { showsEditVehicle = true },
                    onHistory: { presentedDestination = .history },
                    onSettings: { presentedDestination = .settings }
                )
            } else {
                VehicleSetupView(
                    draft: $setupDraft,
                    fieldErrors: showsSetupValidationErrors
                        ? formErrors(for: setupDraft)
                        : .init(),
                    canSubmit: true,
                    onSave: createVehicle
                )
            }
        }
        .sheet(isPresented: $showsEditVehicle) {
            if let vehicle = store.vehicle {
                EditVehicleSheet(
                    initialDraft: vehicle.draft,
                    store: store
                )
            }
        }
        .alert(item: $presentedDestination) { destination in
            Alert(
                title: Text(destination.title),
                message: Text(destination.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(
            "Could not save vehicle",
            isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "An unknown persistence error occurred.")
        }
    }

    private func createVehicle() {
        let errors = validator.validate(setupDraft)
        guard errors.isEmpty else {
            showsSetupValidationErrors = true
            return
        }

        do {
            try store.create(from: setupDraft)
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func formErrors(for draft: VehicleDraft) -> VehicleFormFieldErrors {
        VehicleFormFieldErrors(
            validator.validate(draft).reduce(into: [:]) { result, error in
                result[error.key.formField] = error.value.message
            }
        )
    }
}

private struct EditVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var store: VehicleProfileStore
    @State private var draft: VehicleDraft
    @State private var showsValidationErrors = false
    @State private var persistenceError: String?

    private let validator = VehicleDraftValidator()

    init(initialDraft: VehicleDraft, store: VehicleProfileStore) {
        self.store = store
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            EditVehicleView(
                draft: $draft,
                fieldErrors: showsValidationErrors ? formErrors : .init(),
                canSubmit: true,
                onSave: save,
                onCancel: { dismiss() }
            )
        }
        .alert(
            "Could not save changes",
            isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceError ?? "An unknown persistence error occurred.")
        }
    }

    private var formErrors: VehicleFormFieldErrors {
        VehicleFormFieldErrors(
            validator.validate(draft).reduce(into: [:]) { result, error in
                result[error.key.formField] = error.value.message
            }
        )
    }

    private func save() {
        let errors = validator.validate(draft)
        guard errors.isEmpty else {
            showsValidationErrors = true
            return
        }

        do {
            try store.update(with: draft)
            dismiss()
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}

private enum DebugLaunchConfiguration {
#if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    static var seedsPreviewVehicle: Bool {
        arguments.contains("-seedPreviewVehicle")
    }

    static var resetsPreviewVehicle: Bool {
        arguments.contains("-resetPreviewVehicle")
    }

    static var previewDraft: VehicleDraft {
        var draft = VehicleDraft.lexusNXPreview

        if arguments.contains("-previewFallbackVehicle") {
            draft.nickname = "My BMW"
            draft.make = "BMW"
            draft.model = "330i"
            draft.modelYear = "2021"
            draft.trim = "Sport"
        }

        if let paintArgument = arguments.first(where: {
            $0.hasPrefix("-previewPaintColor=")
        }) {
            let value = String(paintArgument.dropFirst("-previewPaintColor=".count))
            draft.colour = VehiclePaintColor(profileValue: value).rawValue
        }

        return draft
    }

    static var adapterState: AdapterConnectionState {
        seedsPreviewVehicle
            ? .connected(name: "Veepeak OBDCheck BLE")
            : .disconnected
    }

    static var assessment: AssessmentPreview? {
        seedsPreviewVehicle ? .sample : nil
    }
#else
    static let adapterState = AdapterConnectionState.disconnected
    static let assessment: AssessmentPreview? = nil
#endif
}

private enum PlaceholderDestination: String, Identifiable {
    case scan
    case history
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .scan:
            "Vehicle scanning"
        case .history:
            "Scan history"
        case .settings:
            "Settings"
        }
    }

    var message: String {
        switch self {
        case .scan:
            "The guided adapter scan arrives in Milestone 2."
        case .history:
            "Saved scan history arrives in Milestone 2."
        case .settings:
            "App and developer settings arrive in a later milestone."
        }
    }
}

private extension VehicleDraftValidator.Field {
    var formField: VehicleFormField {
        switch self {
        case .nickname:
            .nickname
        case .make:
            .make
        case .model:
            .model
        case .modelYear:
            .modelYear
        case .vinOrPlate:
            .vinOrPlate
        case .mileage:
            .mileage
        case .colour:
            .colour
        case .fuelType:
            .fuelType
        }
    }
}
