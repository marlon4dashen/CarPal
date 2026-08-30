import SwiftData
import Testing
@testable import CarPal

@MainActor
struct VehicleRegistrationCoordinatorTests {
    @Test
    func adapterIdentityDecodeAndConfirmationPersistRegisteredVehicle() async throws {
        let container = try makeContainer()
        let store = VehicleProfileStore(modelContext: container.mainContext)
        let adapter = ScriptedMockAdapter(scenario: .healthy, delay: .zero)
        let backend = makeBackendClient()
        let coordinator = VehicleRegistrationCoordinator(
            sessionManager: AdapterSessionManager(client: adapter, initializer: adapter),
            identityReader: adapter,
            backendClient: backend,
            store: store
        )

        await coordinator.beginConnection()
        #expect(coordinator.phase == .needsModelYear)
        #expect(coordinator.draft.vin == "JTJYARBZ0L2000001")

        coordinator.draft.modelYear = "2020"
        await coordinator.decodeVehicle()
        #expect(coordinator.phase == .confirming)
        #expect(coordinator.draft.make == "LEXUS")
        #expect(coordinator.draft.model == "NX 300")

        coordinator.draft.nickname = "My NX"
        let selectionPolicy = VehicleRegistrationSelectionPolicy()
        coordinator.draft.trim = try #require(
            selectionPolicy.trimOptions(for: coordinator.draft).first
        )
        coordinator.draft.colour = "Silver"
        #expect(!coordinator.canSaveConfirmedVehicle)

        coordinator.draft.colour = try #require(
            selectionPolicy.colourOptions(for: coordinator.draft).first
        )
        #expect(coordinator.canSaveConfirmedVehicle)
        await coordinator.saveConfirmedVehicle()

        #expect(coordinator.phase == .registered)
        #expect(store.vehicle?.nickname == "My NX")
        #expect(store.vehicle?.vin == "JTJYARBZ0L2000001")
        #expect(store.vehicle?.makeSource == APIAttributeSource.vinDecoder.rawValue)
        #expect(store.vehicle?.diagnosticProfileID == "lexus-nx300-2020-na")
        #expect(await backend.decodeRequests.count == 1)
        #expect(await backend.resolveRequests.count == 1)
    }

    @Test
    func failedAdapterConnectionCannotReachRegistrationOrPersistVehicle() async throws {
        let container = try makeContainer()
        let store = VehicleProfileStore(modelContext: container.mainContext)
        let adapter = ScriptedMockAdapter(scenario: .connectionFailure, delay: .zero)
        let coordinator = VehicleRegistrationCoordinator(
            sessionManager: AdapterSessionManager(client: adapter, initializer: adapter),
            identityReader: adapter,
            backendClient: makeBackendClient(),
            store: store
        )

        await coordinator.beginConnection()

        #expect(coordinator.phase == .needsAdapter)
        #expect(coordinator.errorMessage != nil)
        #expect(store.vehicle == nil)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: VehicleProfileEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeBackendClient() -> FixtureVehicleIdentificationClient {
        let eligibility = APIDiagnosticEligibility(
            profileID: "lexus-nx300-2020-na",
            profileVersion: "1.0.0",
            quickScan: .supported,
            healthScan: .supported,
            collectionPlan: "nx300-2020-v1",
            ruleSet: "nx300-2020-rules-v1",
            limitations: []
        )
        return FixtureVehicleIdentificationClient(
            decodeResponse: APIVehicleDecodeResponse(
                schemaVersion: "1",
                candidate: APIVehicleCandidate(
                    vin: .init(value: "JTJYARBZ0L2000001", source: .obd, requiresConfirmation: false),
                    modelYear: .init(value: 2020, source: .user, requiresConfirmation: false),
                    make: .init(value: "LEXUS", source: .vinDecoder, requiresConfirmation: false),
                    model: .init(value: "NX 300", source: .vinDecoder, requiresConfirmation: false),
                    series: .init(value: "NX", source: .vinDecoder, requiresConfirmation: false),
                    vehicleType: .init(value: "MULTIPURPOSE PASSENGER VEHICLE", source: .vinDecoder, requiresConfirmation: false),
                    bodyClass: .init(value: "Sport Utility Vehicle", source: .vinDecoder, requiresConfirmation: false),
                    engineModel: .init(value: "8AR-FTS", source: .oemDatabase, requiresConfirmation: false),
                    engineConfiguration: .init(value: "Inline", source: .vinDecoder, requiresConfirmation: false),
                    displacementL: .init(value: 2.0, source: .vinDecoder, requiresConfirmation: false),
                    engineCylinders: .init(value: 4, source: .vinDecoder, requiresConfirmation: false),
                    fuelTypePrimary: .init(value: "Gasoline", source: .vinDecoder, requiresConfirmation: false),
                    fuelTypeSecondary: .init(value: nil, source: .vinDecoder, requiresConfirmation: true),
                    driveType: .init(value: "AWD", source: .vinDecoder, requiresConfirmation: false),
                    transmissionStyle: .init(value: "Automatic", source: .vinDecoder, requiresConfirmation: false),
                    manufacturer: .init(value: "Toyota Motor Manufacturing Canada", source: .vinDecoder, requiresConfirmation: false),
                    plantCountry: .init(value: "Canada", source: .vinDecoder, requiresConfirmation: false)
                ),
                decodeWarnings: [],
                eligibility: eligibility
            ),
            resolveResponse: APIDiagnosticProfileResolveResponse(
                schemaVersion: "1",
                eligibility: eligibility
            )
        )
    }
}
