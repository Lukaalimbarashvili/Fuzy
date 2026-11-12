import SwiftUI

struct WatchlistTab: View {
    @State private var coordinator = WatchlistCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            WatchlistView(onSelect: { symbol in
                coordinator.trigger(.asset(symbol: symbol))
            })
            .navigationDestination(for: WatchlistRoute.self) { route in
                coordinator.buildView(for: route)
            }
        }
    }
}
