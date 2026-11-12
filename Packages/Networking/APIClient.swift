import Foundation

public enum APIError: Error, Sendable, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decoding(String)
}

/// The one way the rest of the app sends a REST request.
/// A protocol so tests can swap in a mock.
public protocol APIClient: Sendable {
    func send<T: Decodable>(_ endpoint: some Endpoint) async throws -> T
}

public final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let defaultHeaders: [String: String]   // e.g. the API key header, supplied by the app

    public init(session: URLSession = .shared, defaultHeaders: [String: String] = [:]) {
        self.session = session
        self.defaultHeaders = defaultHeaders
    }

    public func send<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        let request = try makeRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func makeRequest(for endpoint: some Endpoint) throws -> URLRequest {
        let fullURL = endpoint.baseURL.appendingPathComponent(endpoint.path)
        guard var components = URLComponents(url: fullURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Endpoint headers win over default headers.
        let headers = defaultHeaders.merging(endpoint.headers) { _, endpointValue in endpointValue }
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
