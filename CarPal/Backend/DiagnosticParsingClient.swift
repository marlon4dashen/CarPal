import Foundation

protocol DiagnosticParsingClient: Sendable {
    func parseTroubleCodes(
        _ request: APITroubleCodeParseRequest
    ) async throws -> APITroubleCodeParseResponse

    func parseReadiness(
        _ request: APIReadinessParseRequest
    ) async throws -> APIReadinessParseResponse
}

final class URLSessionDiagnosticParsingClient: DiagnosticParsingClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func parseTroubleCodes(
        _ request: APITroubleCodeParseRequest
    ) async throws -> APITroubleCodeParseResponse {
        try await post(request, path: "v1/diagnostics/trouble-codes/parse")
    }

    func parseReadiness(
        _ request: APIReadinessParseRequest
    ) async throws -> APIReadinessParseResponse {
        try await post(request, path: "v1/diagnostics/readiness/parse")
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

actor FixtureDiagnosticParsingClient: DiagnosticParsingClient {
    private let troubleCodeResponse: APITroubleCodeParseResponse
    private let readinessResponse: APIReadinessParseResponse
    private(set) var troubleCodeRequests: [APITroubleCodeParseRequest] = []
    private(set) var readinessRequests: [APIReadinessParseRequest] = []

    init(
        troubleCodeResponse: APITroubleCodeParseResponse,
        readinessResponse: APIReadinessParseResponse
    ) {
        self.troubleCodeResponse = troubleCodeResponse
        self.readinessResponse = readinessResponse
    }

    func parseTroubleCodes(
        _ request: APITroubleCodeParseRequest
    ) -> APITroubleCodeParseResponse {
        troubleCodeRequests.append(request)
        return troubleCodeResponse
    }

    func parseReadiness(
        _ request: APIReadinessParseRequest
    ) -> APIReadinessParseResponse {
        readinessRequests.append(request)
        return readinessResponse
    }
}
