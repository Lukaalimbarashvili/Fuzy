//
//  WatchlistView.swift
//  Fuzy
//
//  Created by Luka Alimbarashvili on 10/11/2026.
//

import SwiftUI
import FactoryKit

struct WatchlistView: View {
    @State private var viewModel = WatchlistViewModel()
    let onSelect: (String) -> Void

    init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
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
                Button {
                    onSelect(item.symbol)
                } label: {
                    WatchRow(watchItem: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Loaded") {
    let _ = Container.shared.marketRepo.register { MockMarketRepository() }
    WatchlistView(onSelect: { _ in })
}

#Preview("Error") {
    let _ = Container.shared.marketRepo.register { FailingMarketRepository() }
    WatchlistView(onSelect: { _ in })
}
