//
//  WatchlistView.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import SwiftUI
import Domain

struct WatchlistView: View {
    @State private var viewModel: WatchlistViewModel

    init(repo: MarketRepository) {
        _viewModel = State(initialValue: WatchlistViewModel(repo: repo))
    }

    var body: some View {
        content
            .task {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .error(let message):
            ErrorView(message: message) {
                Task {
                    await viewModel.load()
                }
            }
        case .loading:
            ProgressView()
        case .loaded(let data):
            watchList(items: data)
        }
    }


    private func watchList(items: [WatchItem]) -> some View {
        List {
            ForEach(items) { item in
                WatchRow(watchItem: item)
            }
        }
    }
}
