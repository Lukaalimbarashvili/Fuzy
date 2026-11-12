//
//  FuzyApp.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import SwiftUI
import Domain
import Networking

@main
struct FuzyApp: App {
    private let repo: MarketRepository = LiveMarketRepository(
        api: URLSessionAPIClient(defaultHeaders: ["X-Finnhub-Token": Secrets.finnhubKey])
    )

    var body: some Scene {
        WindowGroup {
            WatchlistView(repo: repo)
        }
    }
}
