import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

/// Describes one HTTP request. Domain types (like `MarketEndpoint`) conform to this.
public protocol Endpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem] { get }
    var headers: [String: String] { get }
}

public extension Endpoint {
    var method: HTTPMethod { .get }
    var query: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
}
