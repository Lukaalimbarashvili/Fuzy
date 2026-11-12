//
//  WatchlistViewModel.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import Foundation
import SwiftUI
import Domain
import Networking

@Observable
final class WatchlistViewModel {
    
    var viewState: ViewState<[WatchItem]> = .loading
    private let repo: MarketRepository
    
    
    let symbols: [String] = ["AAPL", "GOOGL", "IBM"]
    
    init(repo: MarketRepository) {
        self.repo = repo
    }
    
    func load() async {
        viewState = .loading
        var items: [WatchItem] = []

        await withTaskGroup(of: WatchItem?.self) { group in
            for symbol in symbols {
                group.addTask { [repo] in
                    guard let quote = try? await repo.quote(symbol: symbol) else { return nil }
                    return WatchItem(symbol: symbol, description: "\(symbol) Inc",
                                     price: quote.price, changePercent: quote.changePercent)
                }
            }
            for await item in group {
                if let item {
                    items.append(item)
                    items.sort { order(of: $0.symbol) < order(of: $1.symbol) }
                    viewState = .loaded(items)   // list updates with each arrival
                }
            }
        }

        if items.isEmpty { viewState = .error("Check your connection and try again.") }
    }

    private func order(of symbol: String) -> Int {
        symbols.firstIndex(of: symbol) ?? .max
    }
}
