import Foundation
import Domain
import FactoryKit

@Observable
final class AssetDetailViewModel {
    let symbol: String
    var viewState: ViewState<Quote> = .loading

    @ObservationIgnored @Injected(\.marketRepo) private var repo

    init(symbol: String) {
        self.symbol = symbol
    }

    func load() async {
        viewState = .loading
        do {
            viewState = .loaded(try await repo.quote(symbol: symbol))
        } catch is CancellationError {
            return
        } catch {
            viewState = .error("Check your connection and try again.")
        }
    }
}
