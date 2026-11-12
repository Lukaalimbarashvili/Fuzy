import Foundation

/// Every screen the watchlist flow can push. Plain data, so it can live in a NavigationPath.
enum WatchlistRoute: Hashable {
    case asset(symbol: String)
}
