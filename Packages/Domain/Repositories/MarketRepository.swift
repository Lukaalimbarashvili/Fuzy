import Foundation
import Networking

public protocol MarketRepository: Sendable {
    func quote(symbol: String) async throws -> Quote
}

public struct LiveMarketRepository: MarketRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func quote(symbol: String) async throws -> Quote {
        try await api.send(MarketEndpoint.quote(symbol: symbol))
    }
}
