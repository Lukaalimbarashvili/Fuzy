import FactoryKit
import Domain
import Networking

extension Container {
    var apiClient: Factory<APIClient> {
        self {
            URLSessionAPIClient(defaultHeaders: ["X-Finnhub-Token": Secrets.finnhubKey])
        }
        .singleton
    }

    var marketRepo: Factory<MarketRepository> {
        self { LiveMarketRepository(api: self.apiClient()) }
    }
}
