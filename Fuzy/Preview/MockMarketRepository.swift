import Foundation
import Domain

/// Returns fixed quotes after a short delay. For previews only.
struct MockMarketRepository: MarketRepository {
    func quote(symbol: String) async throws -> Quote {
        try await Task.sleep(for: .milliseconds(500))
        return Quote(
            price: 123.45,
            change: 1.23,
            changePercent: 1.01,
            high: 125,
            low: 120,
            open: 121,
            previousClose: 122.22,
            timestamp: Int(Date().timeIntervalSince1970)
        )
    }
}

/// Always throws, to preview the error state.
struct FailingMarketRepository: MarketRepository {
    func quote(symbol: String) async throws -> Quote {
        try await Task.sleep(for: .milliseconds(500))
        throw URLError(.notConnectedToInternet)
    }
}
