import Foundation
import Observation

@MainActor
@Observable
final class VehicleRegistrationCoordinator {
    enum Phase: Equatable, Sendable {
        case needsAdapter
        case connecting
        case readingIdentity
        case needsVINRecovery
        case needsModelYear
        case decoding
        case confirming
        case saving
        case registered
    }

    private let sessionManager: AdapterSessionManager
    private let identityReader: any VehicleIdentityReading
    private let backendClient: any VehicleIdentificationClient
    private let store: VehicleProfileStore
    private let selectionPolicy = VehicleRegistrationSelectionPolicy()

    private(set) var phase: Phase = .needsAdapter
    private(set) var obdIdentity: OBDVehicleIdentity?
    private(set) var candidate: APIVehicleCandidate?
    private(set) var eligibility: APIDiagnosticEligibility?
    private(set) var decodeWarnings: [String] = []
    private(set) var errorMessage: String?
    var draft = VehicleRegistrationDraft()

    init(
        sessionManager: AdapterSessionManager,
        identityReader: any VehicleIdentityReading,
        backendClient: any VehicleIdentificationClient,
        store: VehicleProfileStore
    ) {
        self.sessionManager = sessionManager
        self.identityReader = identityReader
        self.backendClient = backendClient
        self.store = store
    }

    var adapterState: AdapterConnectionState {
        sessionManager.connectionState
    }

    var canSaveConfirmedVehicle: Bool {
        guard let candidate else { return false }
        return draft.canSave
            && draft.matchesLockedIdentity(candidate)
            && draft.matchesLockedPowertrain(candidate)
            && selectionPolicy.validates(draft)
    }

    func beginConnection() async {
        guard phase != .connecting, phase != .readingIdentity else { return }
        errorMessage = nil
        phase = .connecting

        do {
            _ = try await sessionManager.prepareConnection()
            guard sessionManager.connectionState.isReadyForScan else {
                throw RegistrationError.vehicleSessionNotReady
            }
            phase = .readingIdentity
            let identity = try await identityReader.readVehicleIdentity()
            obdIdentity = identity
            if let vin = identity.vin {
                draft.vin = vin
                phase = .needsModelYear
            } else {
                phase = .needsVINRecovery
            }
        } catch is CancellationError {
            phase = .needsAdapter
        } catch {
            errorMessage = Self.message(for: error)
            phase = .needsAdapter
        }
    }

    func acceptRecoveredVIN() {
        guard phase == .needsVINRecovery,
              sessionManager.connectionState.isReadyForScan,
              Self.isValidVIN(draft.vin) else {
            errorMessage = "Enter a valid 17-character VIN while the adapter remains ready."
            return
        }
        draft.vin = draft.vin.uppercased()
        errorMessage = nil
        phase = .needsModelYear
    }

    func decodeVehicle() async {
        guard phase == .needsModelYear,
              sessionManager.connectionState.isReadyForScan,
              let identity = obdIdentity,
              let year = Int(draft.modelYear),
              draft.canDecode else {
            errorMessage = "Confirm a valid model year before decoding the vehicle."
            return
        }

        errorMessage = nil
        phase = .decoding
        do {
            let response = try await backendClient.decodeVehicle(
                APIVehicleDecodeRequest(
                    vin: draft.vin,
                    modelYear: year,
                    obdIdentity: identity.apiIdentity,
                    adapter: identity.adapterMetadata
                )
            )
            candidate = response.candidate
            eligibility = response.eligibility
            decodeWarnings = response.decodeWarnings
            draft = VehicleRegistrationDraft(candidate: response.candidate)
            phase = .confirming
        } catch {
            errorMessage = Self.message(for: error)
            phase = .needsModelYear
        }
    }

    func saveConfirmedVehicle() async {
        guard phase == .confirming,
              sessionManager.connectionState.isReadyForScan,
              let identity = obdIdentity,
              let originalCandidate = candidate,
              canSaveConfirmedVehicle else {
            errorMessage = "Choose valid vehicle details from the available options before saving."
            return
        }

        errorMessage = nil
        phase = .saving
        do {
            let confirmedCandidate = originalCandidate.applying(draft)
            let resolved = try await backendClient.resolveDiagnosticProfile(
                APIDiagnosticProfileResolveRequest(
                    identity: confirmedCandidate,
                    obdIdentity: identity.apiIdentity,
                    adapter: identity.adapterMetadata
                )
            )
            eligibility = resolved.eligibility
            try store.create(
                from: ConfirmedVehicleRegistration(
                    draft: draft.vehicleDraft,
                    vin: draft.vin,
                    engineModel: draft.engineModel,
                    driveType: draft.driveType,
                    transmissionStyle: draft.transmissionStyle,
                    makeSource: confirmedCandidate.make.source,
                    modelSource: confirmedCandidate.model.source,
                    modelYearSource: confirmedCandidate.modelYear.source,
                    engineSource: confirmedCandidate.engineModel.source,
                    fuelTypeSource: confirmedCandidate.fuelTypePrimary.source,
                    driveTypeSource: confirmedCandidate.driveType.source,
                    diagnosticEligibility: resolved.eligibility
                )
            )
            phase = .registered
        } catch {
            errorMessage = Self.message(for: error)
            phase = .confirming
        }
    }

    func changeVINOrYear() {
        guard phase == .confirming else { return }
        candidate = nil
        eligibility = nil
        decodeWarnings = []
        phase = .needsModelYear
    }

    private static func isValidVIN(_ vin: String) -> Bool {
        let normalized = vin.uppercased()
        return normalized.count == 17
            && normalized.allSatisfy { character in
                character.isASCII
                    && (character.isLetter || character.isNumber)
                    && !["I", "O", "Q"].contains(character.uppercased())
            }
    }

    private static func message(for error: Error) -> String {
        if case let BackendClientError.api(_, message, _) = error {
            return message
        }
        if let error = error as? OBDTransportError {
            return error.description
        }
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "CarPal could not complete registration. Check the connection and try again."
    }

    private enum RegistrationError: Error {
        case vehicleSessionNotReady
    }
}

private extension OBDVehicleIdentity {
    var apiIdentity: APIOBDIdentity {
        APIOBDIdentity(
            calibrationIDs: calibrationIDs,
            ecuNames: ecuNames,
            supportedModes: supportedModes
        )
    }

    var adapterMetadata: APIAdapterMetadata {
        APIAdapterMetadata(
            model: "veepeak-obdcheck-ble",
            protocol: protocolDescription,
            market: "CA"
        )
    }
}

private extension VehicleRegistrationDraft {
    init(candidate: APIVehicleCandidate) {
        let make = candidate.make.value ?? ""
        let model = candidate.model.value ?? ""
        self.init(
            nickname: [make, model].filter { !$0.isEmpty }.joined(separator: " "),
            vin: candidate.vin.value ?? "",
            modelYear: candidate.modelYear.value.map(String.init) ?? "",
            make: make,
            model: model,
            engineModel: candidate.engineModel.value ?? "",
            fuelType: candidate.fuelTypePrimary.value ?? "",
            driveType: candidate.driveType.value ?? "",
            transmissionStyle: candidate.transmissionStyle.value ?? ""
        )
    }

    func matchesLockedIdentity(_ candidate: APIVehicleCandidate) -> Bool {
        vin == (candidate.vin.value ?? "")
            && modelYear == candidate.modelYear.value.map(String.init)
            && make == (candidate.make.value ?? "")
            && model == (candidate.model.value ?? "")
            && engineModel == (candidate.engineModel.value ?? "")
    }

    func matchesLockedPowertrain(_ candidate: APIVehicleCandidate) -> Bool {
        fuelType == (candidate.fuelTypePrimary.value ?? "")
            && driveType == (candidate.driveType.value ?? "")
            && transmissionStyle == (candidate.transmissionStyle.value ?? "")
    }
}

private extension APIVehicleCandidate {
    func applying(_ draft: VehicleRegistrationDraft) -> APIVehicleCandidate {
        APIVehicleCandidate(
            vin: vin.replacing(with: draft.vin),
            modelYear: modelYear.replacing(with: Int(draft.modelYear)),
            make: make.replacing(with: draft.make),
            model: model.replacing(with: draft.model),
            series: series,
            vehicleType: vehicleType,
            bodyClass: bodyClass,
            engineModel: engineModel.replacing(with: draft.engineModel),
            engineConfiguration: engineConfiguration,
            displacementL: displacementL,
            engineCylinders: engineCylinders,
            fuelTypePrimary: fuelTypePrimary.replacing(with: draft.fuelType),
            fuelTypeSecondary: fuelTypeSecondary,
            driveType: driveType.replacing(with: draft.driveType),
            transmissionStyle: transmissionStyle.replacing(with: draft.transmissionStyle),
            manufacturer: manufacturer,
            plantCountry: plantCountry
        )
    }
}

private extension APIVehicleAttribute where Value == String {
    func replacing(with newValue: String) -> Self {
        let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != (value ?? "") else { return self }
        return APIVehicleAttribute(
            value: normalized.isEmpty ? nil : normalized,
            source: .user,
            requiresConfirmation: normalized.isEmpty
        )
    }
}

private extension APIVehicleAttribute where Value == Int {
    func replacing(with newValue: Int?) -> Self {
        guard newValue != value else { return self }
        return APIVehicleAttribute(
            value: newValue,
            source: .user,
            requiresConfirmation: newValue == nil
        )
    }
}
