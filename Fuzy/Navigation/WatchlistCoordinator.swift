import SwiftUI
import os

private let logger = Logger(subsystem: "lukas.Fuzy", category: "navigation")

@Observable
final class WatchlistCoordinator {
    var path = NavigationPath()

    func trigger(_ route: WatchlistRoute) {
        logger.info("push \(String(describing: route))")
        path.append(route)
    }

    @ViewBuilder
    func buildView(for route: WatchlistRoute) -> some View {
        switch route {
        case .asset(let symbol):
            AssetDetailView(symbol: symbol)
        }
    }
}
