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

    @State private var path: [VehicleAppRoute] = []
    @State private var presentedDestination: PlaceholderDestination?
    @State private var showsEditVehicle = false
    @State private var vehicleIntegration = DebugLaunchConfiguration.usesMockAdapter
        ? VehicleIntegration.scripted()
        : VehicleIntegration.live()
    private let backendClient = BackendConfiguration.vehicleIdentificationClient

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let vehicle = store.vehicle {
                    VehicleHomeView(
                        vehicle: vehicle.draft,
                        adapterState: adapterState,
                        assessment: latestAssessment,
                        onCheckAdapter: checkAdapterConnection,
                        onScan: startScan,
                        onEdit: { showsEditVehicle = true },
                        onHistory: { path.append(.history) },
                        onSettings: { presentedDestination = .settings }
                    )
                } else {
                    VehicleRegistrationView(
                        store: store,
                        integration: vehicleIntegration,
                        backendClient: backendClient
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
                    engineModel: vehicle.engineModel,
                    store: store,
                    onUnregister: unregisterVehicle
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
        vehicleIntegration.sessionManager.connectionState
    }

    private var scanCoordinator: ScanCoordinator {
        ScanCoordinator(
            sessionManager: vehicleIntegration.sessionManager,
            diagnostics: vehicleIntegration.diagnostics
        )
    }

    private func checkAdapterConnection() {
        guard adapterState != .searching else { return }
        Task {
            do {
                try await vehicleIntegration.sessionManager.prepareConnection()
            } catch is CancellationError {
                // A scan can take ownership of discovery without showing a stale failure.
            } catch {
                // The observable adapter state already presents the actionable failure.
            }
        }
    }

    private func startScan() {
        guard adapterState.isReadyForScan else { return }
        path.append(.scan)
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

    private func unregisterVehicle() throws {
        guard let vehicleID = store.vehicle?.id else {
            throw VehicleProfileStore.StoreError.profileNotFound
        }
        try historyStore.clear(vehicleID: vehicleID)
        try store.unregister()
        vehicleIntegration.sessionManager.disconnect()
        path.removeAll()
        showsEditVehicle = false
    }
}

private struct EditVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var store: VehicleProfileStore
    @State private var draft: VehicleDraft
    private let engineModel: String
    private let onUnregister: () throws -> Void
    @State private var persistenceError: String?

    private let selectionPolicy = VehicleRegistrationSelectionPolicy()

    init(
        initialDraft: VehicleDraft,
        engineModel: String,
        store: VehicleProfileStore,
        onUnregister: @escaping () throws -> Void
    ) {
        self.store = store
        self.engineModel = engineModel
        self.onUnregister = onUnregister
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            EditVehicleView(
                draft: $draft,
                engineModel: engineModel,
                canSubmit: canSave,
                onSave: save,
                onUnregister: unregister,
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

    private var canSave: Bool {
        let mileage = draft.mileage.trimmingCharacters(in: .whitespacesAndNewlines)
        let mileageIsValid = mileage.isEmpty
            || Double(mileage).map { $0.isFinite && $0 >= 0 } == true
        return mileageIsValid
            && selectionPolicy.validates(VehicleRegistrationDraft(profile: draft))
    }

    private func save() {
        guard canSave else { return }

        do {
            try store.updatePresentation(
                trim: draft.trim,
                colour: draft.colour,
                mileage: draft.mileage
            )
            dismiss()
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func unregister() {
        do {
            try onUnregister()
            dismiss()
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}

private enum DebugLaunchConfiguration {
#if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    static var usesMockAdapter: Bool {
        arguments.contains("-useMockAdapter")
    }

    static var assessment: AssessmentPreview? {
        nil
    }
#else
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
