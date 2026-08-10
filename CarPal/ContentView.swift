import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var store: VehicleProfileStore?
    @State private var historyStore: ScanHistoryStore?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let store, let historyStore {
                VehicleAppFlow(store: store, historyStore: historyStore)
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
        let historyStore = ScanHistoryStore(modelContext: modelContext)

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
            if let vehicle = store.vehicle {
                try historyStore.load(vehicleID: vehicle.id)
            }
            self.store = store
            self.historyStore = historyStore
        } catch {
            loadError = "CarPal could not load the saved vehicle. \(error.localizedDescription)"
        }
    }
}

private struct VehicleAppFlow: View {
    @Bindable var store: VehicleProfileStore
    @Bindable var historyStore: ScanHistoryStore

    @State private var setupDraft = VehicleDraft()
    @State private var showsSetupValidationErrors = false
    @State private var path: [VehicleAppRoute] = DebugLaunchConfiguration.startsMockScan
        ? [.scan]
        : []
    @State private var presentedDestination: PlaceholderDestination?
    @State private var showsEditVehicle = false
    @State private var persistenceError: String?
    @State private var liveAdapter = CoreBluetoothOBDClient()

    private let validator = VehicleDraftValidator()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let vehicle = store.vehicle {
                    VehicleHomeView(
                        vehicle: vehicle.draft,
                        adapterState: adapterState,
                        assessment: latestAssessment,
                        onCheckAdapter: checkAdapterConnection,
                        onScan: { path.append(.scan) },
                        onEdit: { showsEditVehicle = true },
                        onHistory: { path.append(.history) },
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
            .navigationDestination(for: VehicleAppRoute.self) { route in
                destination(for: route)
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

    @ViewBuilder
    private func destination(for route: VehicleAppRoute) -> some View {
        switch route {
        case .scan:
            if let vehicle = store.vehicle {
                ScanProcessView(vehicleID: vehicle.id, coordinator: scanCoordinator) { result in
                    try historyStore.save(result)
                    path.append(.result(result.id))
                }
            } else {
                ContentUnavailableView("Vehicle unavailable", systemImage: "car.fill")
            }
        case let .result(id):
            if let result = historyStore.result(id: id) {
                ScanResultView(
                    result: result,
                    onPrimaryAction: { handlePrimaryAction(for: result) },
                    onHome: { path.removeAll() }
                )
            } else {
                ContentUnavailableView(
                    "Scan result unavailable",
                    systemImage: "exclamationmark.triangle"
                )
            }
        case .history:
            ScanHistoryView(results: historyStore.results) { id in
                path.append(.result(id))
            }
        }
    }

    private var adapterState: AdapterConnectionState {
        DebugLaunchConfiguration.usesMockAdapter
            ? .connected(name: "Veepeak OBDCheck BLE (Mock)")
            : liveAdapter.connectionState
    }

    private var scanCoordinator: ScanCoordinator {
        if DebugLaunchConfiguration.usesMockAdapter {
            return ScanCoordinator(scenario: .serviceSoon)
        }
        return ScanCoordinator(adapterClient: liveAdapter, obdClient: liveAdapter)
    }

    private func checkAdapterConnection() {
        guard liveAdapter.connectionState != .searching else { return }
        Task {
            do {
                try await liveAdapter.prepareConnection()
            } catch is CancellationError {
                // A scan can take ownership of discovery without showing a stale failure.
            } catch {
                // The observable adapter state already presents the actionable failure.
            }
        }
    }

    private var latestAssessment: AssessmentPreview? {
        if let latest = historyStore.results.first {
            return AssessmentPreview(
                status: latest.status,
                score: latest.score,
                completeness: latest.completeness,
                scannedAt: latest.scannedAt,
                nextAction: latest.action.title
            )
        }
        return DebugLaunchConfiguration.assessment
    }

    private func handlePrimaryAction(for result: ScanResult) {
        if result.action == .scanAgain {
            path = [.scan]
        } else {
            path.removeAll()
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

    static var startsMockScan: Bool {
        arguments.contains("-startMockScan")
    }

    static var usesMockAdapter: Bool {
        startsMockScan || arguments.contains("-useMockAdapter")
    }

    static var previewDraft: VehicleDraft {
        var draft = arguments.contains("-previewRX2023")
            ? VehicleDraft(
                nickname: "My Lexus RX",
                make: "Lexus",
                model: "RX",
                modelYear: "2023",
                variant: "RX 350",
                vinOrPlate: "CARPALRX",
                mileage: "24000",
                trim: "Premium",
                colour: "Nori Green Pearl",
                fuelType: "Gasoline"
            )
            : .lexusNXPreview

        if let paintArgument = arguments.first(where: {
            $0.hasPrefix("-previewPaintColor=")
        }) {
            let value = String(paintArgument.dropFirst("-previewPaintColor=".count))
            let requested = VehiclePaintColor(profileValue: value)
            let catalog = LexusVehicleCatalogRepository.shared
            draft.colour = catalog.colors(for: draft).first {
                catalog.renderColor(for: $0.name) == requested
            }?.name ?? draft.colour
        }

        return draft
    }

    static var assessment: AssessmentPreview? {
        seedsPreviewVehicle ? .sample : nil
    }
#else
    static let startsMockScan = false
    static let usesMockAdapter = false
    static let assessment: AssessmentPreview? = nil
#endif
}

private enum PlaceholderDestination: String, Identifiable {
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .settings:
            "Settings"
        }
    }

    var message: String {
        switch self {
        case .settings:
            "App and developer settings arrive in a later milestone."
        }
    }
}

private enum VehicleAppRoute: Hashable {
    case scan
    case result(UUID)
    case history
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
        case .variant:
            .variant
        case .vinOrPlate:
            .vinOrPlate
        case .mileage:
            .mileage
        case .trim:
            .trim
        case .colour:
            .colour
        case .fuelType:
            .fuelType
        }
    }
}
