import Foundation
import Observation

enum DiagnosticToolLoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(DiagnosticToolFailure)

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}

@MainActor
@Observable
final class TroubleCodesToolModel {
    private let reader: any TroubleCodeReading
    private(set) var state: DiagnosticToolLoadState<TroubleCodeReport> = .idle

    init(reader: any TroubleCodeReading) {
        self.reader = reader
    }

    func load() async {
        guard !state.isLoading else { return }
        state = .loading
        do {
            state = .loaded(try await reader.readTroubleCodes())
        } catch {
            state = .failed(Self.failure(for: error))
        }
    }

    private static func failure(for error: Error) -> DiagnosticToolFailure {
        DiagnosticToolFailureMapper.map(error)
    }
}

@MainActor
@Observable
final class ReadinessToolModel {
    private let reader: any ReadinessReading
    private(set) var state: DiagnosticToolLoadState<ReadinessReport> = .idle

    init(reader: any ReadinessReading) {
        self.reader = reader
    }

    func load() async {
        guard !state.isLoading else { return }
        state = .loading
        do {
            state = .loaded(try await reader.readReadiness())
        } catch {
            state = .failed(DiagnosticToolFailureMapper.map(error))
        }
    }
}

private enum DiagnosticToolFailureMapper {
    static func map(_ error: Error) -> DiagnosticToolFailure {
        if error is CancellationError { return .cancelled }
        if let capabilityError = error as? DiagnosticCapabilityError {
            return switch capabilityError {
            case .unsupported: .unsupported
            case .malformedResponse: .invalidVehicleResponse
            }
        }
        if let backendError = error as? BackendClientError {
            return switch backendError {
            case .invalidResponse:
                .backendUnavailable
            case let .api(code, _, _):
                switch code {
                case "DIAGNOSTIC_DATA_UNAVAILABLE": .unsupported
                case "DIAGNOSTIC_RESPONSE_INVALID": .invalidVehicleResponse
                default: .backendUnavailable
                }
            }
        }
        if error is URLError { return .backendUnavailable }
        if let transportError = error as? OBDTransportError {
            return switch transportError {
            case .bluetoothUnavailable, .adapterNotFound, .serialChannelUnavailable,
                    .notificationsUnavailable:
                .adapterUnavailable
            case .connectionFailed:
                .connectionLost
            case .commandTimedOut:
                .timedOut
            case .invalidResponse:
                .invalidVehicleResponse
            case .adapterRejectedCommand:
                .unsupported
            }
        }
        return .unknown
    }
}
