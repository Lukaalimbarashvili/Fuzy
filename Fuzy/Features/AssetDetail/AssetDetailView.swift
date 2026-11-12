import SwiftUI
import Domain
import FactoryKit

struct AssetDetailView: View {
    @State private var viewModel: AssetDetailViewModel

    init(symbol: String) {
        _viewModel = State(initialValue: AssetDetailViewModel(symbol: symbol))
    }

    var body: some View {
        content
            .navigationTitle(viewModel.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading:
            ProgressView()
        case .error(let message):
            ErrorView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded(let quote):
            details(quote)
        }
    }

    private func details(_ quote: Quote) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.price.formatted(.currency(code: "USD")))
                        .font(.largeTitle.bold())
                    Text(changeText(quote.changePercent))
                        .foregroundStyle(changeColor(quote.changePercent))
                }
            }
            Section("Today") {
                row("Open", quote.open)
                row("High", quote.high)
                row("Low", quote.low)
                row("Previous close", quote.previousClose)
            }
        }
    }

    private func row(_ title: String, _ value: Double) -> some View {
        LabeledContent(title, value: value.formatted(.currency(code: "USD")))
    }

    private func changeText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.2f%%", value)
    }

    private func changeColor(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        return value >= 0 ? .green : .red
    }
}

#Preview("Loaded") {
    let _ = Container.shared.marketRepo.register { MockMarketRepository() }
    NavigationStack { AssetDetailView(symbol: "AAPL") }
}

#Preview("Error") {
    let _ = Container.shared.marketRepo.register { FailingMarketRepository() }
    NavigationStack { AssetDetailView(symbol: "AAPL") }
}
