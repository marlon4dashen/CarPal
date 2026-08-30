import Foundation

protocol VehicleIdentificationClient: Sendable {
    func decodeVehicle(
        _ request: APIVehicleDecodeRequest
    ) async throws -> APIVehicleDecodeResponse

    func resolveDiagnosticProfile(
        _ request: APIDiagnosticProfileResolveRequest
    ) async throws -> APIDiagnosticProfileResolveResponse
}

enum BackendClientError: Error, Equatable, Sendable {
    case invalidResponse
    case api(code: String, message: String, retryable: Bool)
}

final class URLSessionVehicleIdentificationClient: VehicleIdentificationClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func decodeVehicle(
        _ request: APIVehicleDecodeRequest
    ) async throws -> APIVehicleDecodeResponse {
        try await post(request, path: "v1/vehicle-identification/decode")
    }

    func resolveDiagnosticProfile(
        _ request: APIDiagnosticProfileResolveRequest
    ) async throws -> APIDiagnosticProfileResolveResponse {
        try await post(request, path: "v1/diagnostic-profiles/resolve")
    }

    private func post<Request: Encodable, Response: Decodable>(
        _ payload: Request,
        path: String
    ) async throws -> Response {
        let url = path.split(separator: "/").reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.carPalAPI().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder.carPalAPI().decode(APIErrorResponse.self, from: data) {
                throw BackendClientError.api(
                    code: apiError.error.code,
                    message: apiError.error.message,
                    retryable: apiError.error.retryable
                )
            }
            throw BackendClientError.invalidResponse
        }
        return try JSONDecoder.carPalAPI().decode(Response.self, from: data)
    }
}

actor FixtureVehicleIdentificationClient: VehicleIdentificationClient {
    private let decodeResponse: APIVehicleDecodeResponse
    private let resolveResponse: APIDiagnosticProfileResolveResponse
    private(set) var decodeRequests: [APIVehicleDecodeRequest] = []
    private(set) var resolveRequests: [APIDiagnosticProfileResolveRequest] = []

    init(
        decodeResponse: APIVehicleDecodeResponse,
        resolveResponse: APIDiagnosticProfileResolveResponse
    ) {
        self.decodeResponse = decodeResponse
        self.resolveResponse = resolveResponse
    }

    func decodeVehicle(
        _ request: APIVehicleDecodeRequest
    ) async -> APIVehicleDecodeResponse {
        decodeRequests.append(request)
        return decodeResponse
    }

    func resolveDiagnosticProfile(
        _ request: APIDiagnosticProfileResolveRequest
    ) async -> APIDiagnosticProfileResolveResponse {
        resolveRequests.append(request)
        return resolveResponse
    }
}
