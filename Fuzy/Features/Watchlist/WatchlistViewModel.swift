//
//  WatchlistViewModel.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import Foundation
import SwiftUI

@Observable
final class WatchlistViewModel {

    var viewState: ViewState<[WatchItem]> = .loading

    func load() async {

        viewState = .loading

        do {
            try await Task.sleep(for: .seconds(1))
            viewState = .loaded([
                .init(id: "1", instrument: "aapl", desciption: "AAPL Inc", price: 540, change: 41),
                .init(id: "2", instrument: "GOOGL", desciption: "GOOGL Inc", price: 412, change: 41),
                .init(id: "3", instrument: "IBM", desciption: "IBM Inc", price: 12, change: 3)
            ])
        } catch is CancellationError {
            return                    
        } catch {
            viewState = .error("Check your connection and try again.")
        }
    }
}
