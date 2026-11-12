import Foundation
import Networking

public enum MarketEndpoint: Endpoint {
    case quote(symbol: String)

    public var baseURL: URL {
        URL(string: "https://finnhub.io")!   // constant literal, safe to unwrap
    }

    public var path: String {
        switch self {
        case .quote: "/api/v1/quote"
        }
    }

    public var query: [URLQueryItem] {
        switch self {
        case .quote(let symbol): [URLQueryItem(name: "symbol", value: symbol)]
        }
    }
}
