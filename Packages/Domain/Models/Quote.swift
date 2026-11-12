import Foundation

/// A stock price snapshot, decoded from Finnhub's `/quote` response.
public struct Quote: Decodable, Sendable, Equatable {
    public let price: Double
    public let change: Double?           // Finnhub sends null when it has no data (e.g. unknown symbol)
    public let changePercent: Double?
    public let high: Double
    public let low: Double
    public let open: Double
    public let previousClose: Double
    public let timestamp: Int            // Unix seconds

    public var date: Date { Date(timeIntervalSince1970: TimeInterval(timestamp)) }

    public init(
        price: Double,
        change: Double?,
        changePercent: Double?,
        high: Double,
        low: Double,
        open: Double,
        previousClose: Double,
        timestamp: Int
    ) {
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.high = high
        self.low = low
        self.open = open
        self.previousClose = previousClose
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case price = "c"
        case change = "d"
        case changePercent = "dp"
        case high = "h"
        case low = "l"
        case open = "o"
        case previousClose = "pc"
        case timestamp = "t"
    }
}
