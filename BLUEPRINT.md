# Blueprint: build a mini trading app by hand, the Derayah way

Purpose: a practice project (working name **Tickr**) that copies the *shape* of the Derayah iOS app: layers,
networking, sockets, navigation, DI, state, flags, tests. You write every line yourself.

Source of this plan: reading the Derayah code (see [ONBOARDING.md](ONBOARDING.md) and [CODE_TOUR.md](CODE_TOUR.md)).
Nothing here was compiled or run, so treat code blocks as sketches to type out and fix, not paste.
Copy this file into the new project as `BLUEPRINT.md`.

---

## 0. Ground rules

1. **Type it, don't paste it.** If a snippet confuses you, stop and read the matching Derayah file (table in section 12).
2. **One milestone at a time.** Each has a "Done when" check. Commit after each.
3. **Mirror the structure, not the flaws.** Derayah has 1,700-line view models, global singletons and copy-pasted alerts.
   Learn from the layering, avoid those habits (section 11).
4. iOS 17+, SwiftUI, `async`/`await`, `@Observable`, Swift Testing. No Combine unless you must.

## 1. What you are building

A watchlist app with two kinds of data:

| Kind | Example | Technique |
|---|---|---|
| Request/response | Quote (price, day high/low, change), symbol search | REST, one `await` |
| Live stream | Last trade price ticking | WebSocket, `AsyncStream` |

Assets are **US stocks** (AAPL, GOOGL, MSFT, TSLA) served by Finnhub.

Screens: **Watchlist** (list + live prices) → **Asset detail** (quote stats, live price) → **Search** (find and add a symbol) → **Settings** (debug flags).

## 2. Data sources (free)

Use **Finnhub** (https://finnhub.io, docs at https://finnhub.io/docs/api). It has a free key, REST and a free WebSocket.

| Need | Endpoint | Notes |
|---|---|---|
| Quote | `GET https://finnhub.io/api/v1/quote?symbol=AAPL` | Returns `c` current, `d` change, `dp` percent change, `h` high, `l` low, `o` open, `pc` previous close, `t` time |
| Symbol search | `GET https://finnhub.io/api/v1/search?q=apple` | `result[]` with `symbol`, `description`, `type` |
| Live | `wss://ws.finnhub.io?token=KEY`, then send `{"type":"subscribe","symbol":"AAPL"}` | Trade messages: `{"type":"trade","data":[{"s":"AAPL","p":350.1,"t":1699999999999,"v":10}]}` |

Verify field names, plan limits (symbols per socket, calls per minute) and which endpoints are free in the Finnhub docs before coding. Do not trust this table blindly.

**Market hours:** the socket only sends trades while the US market is open, weekdays about 9:30 to 16:00 Eastern (roughly 18:30 to 01:00 in Tbilisi). Outside that window nothing ticks. Show the last REST quote and a "market closed" hint instead of an empty row. For testing after hours, see the optional Binance provider in M5b.

**API key:** never commit it or paste it into chat. Put it in a git-ignored `Secrets.xcconfig` (`FINNHUB_KEY = ...`), expose it through an Info.plist entry (`FinnhubKey = $(FINNHUB_KEY)`), and read it at runtime with `Bundle.main.object(forInfoDictionaryKey:)`. The app passes the key into the networking layer; the packages never read the bundle themselves.

## 3. Architecture (the Derayah layering)

```
App target (Tickr)         views, view models, coordinators, DI registrations
   │ depends on
Domain package             models, repository protocols + implementations, use cases
   │ depends on
Networking package         Endpoint, APIClient, SocketService, providers
```

Rules (same as Derayah's `.cursor/rules.md`):
- Views never import networking. Views talk to a view model. View models talk to a use case or repository **protocol**.
- Dependencies point one way: App → Domain → Networking. A lower layer never imports a higher one.
- Every external dependency (repository, socket) is a protocol, so tests can swap in a mock.

### Folder layout

```
Tickr/
├─ Package.swift                    # one local package, several targets (like Derayah's root Package.swift)
├─ Packages/
│  ├─ Networking/                   # target "Networking"
│  │   ├─ Rest/                     # Endpoint.swift, APIClient.swift, URLSessionAPIClient.swift
│  │   └─ Socket/                   # SocketProvider.swift, SocketService.swift, FinnhubProvider.swift
│  └─ Domain/                       # target "Domain" (depends on Networking)
│      ├─ Models/                   # Quote, PriceTick, SearchResult
│      ├─ Endpoints/                # MarketEndpoint.swift (enum)
│      ├─ Repositories/             # MarketRepository.swift (protocol + impl)
│      └─ UseCases/
├─ Tickr/                           # app target
│  ├─ TickrApp.swift                # @main
│  ├─ AppRootManager.swift
│  ├─ DI/                           # Container+Registrations.swift
│  ├─ Routing/                      # Navigation, Coordinator, Routes
│  ├─ Features/
│  │   ├─ Watchlist/  (WatchlistView, WatchlistViewModel, WatchlistCoordinator)
│  │   ├─ AssetDetail/
│  │   └─ Settings/
│  └─ Debug/                        # FeatureFlags, debug sheet
└─ TickrTests/
```

In `Package.swift`, give each target a `path:` and list its dependencies. Folders **inside** a target are only
organization; target dependencies are what enforce layering.

## 4. Networking: REST (milestone M2)

The Derayah shape: **enum case → repository method → one generic sender**.

```swift
// Networking/Rest/Endpoint.swift
public enum HTTPMethod: String { case get = "GET", post = "POST" }

public protocol Endpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem] { get }
    var headers: [String: String] { get }
}
public extension Endpoint {
    var method: HTTPMethod { .get }
    var query: [URLQueryItem] { [] }
    var headers: [String: String] { [:] }
}
```

```swift
// Domain/Endpoints/MarketEndpoint.swift  (like Derayah's `authentication` enum)
public enum MarketEndpoint: Endpoint {
    case quote(symbol: String)
    case search(query: String)

    public var baseURL: URL { URL(string: "https://finnhub.io")! }
    public var path: String {
        switch self {
        case .quote:  "/api/v1/quote"
        case .search: "/api/v1/search"
        }
    }
    public var query: [URLQueryItem] {
        switch self {
        case .quote(let s):  [.init(name: "symbol", value: s)]
        case .search(let q): [.init(name: "q", value: q)]
        }
    }
}
```

```swift
// Networking/Rest/APIClient.swift
public protocol APIClient {
    func send<T: Decodable>(_ endpoint: some Endpoint) async throws -> T
}

public final class URLSessionAPIClient: APIClient {
    private let session: URLSession
    private let defaultHeaders: [String: String]       // e.g. ["X-Finnhub-Token": key]; check the Finnhub docs for the auth header
    public init(session: URLSession = .shared, defaultHeaders: [String: String] = [:]) {
        self.session = session
        self.defaultHeaders = defaultHeaders
    }

    public func send<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        var comps = URLComponents(url: endpoint.baseURL.appendingPathComponent(endpoint.path),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = endpoint.method.rawValue
        defaultHeaders.merging(endpoint.headers) { _, endpointValue in endpointValue }
            .forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

```swift
// Domain/Repositories/MarketRepository.swift
public protocol MarketRepository {
    func quote(symbol: String) async throws -> Quote
}
public struct LiveMarketRepository: MarketRepository {
    let api: APIClient
    public func quote(symbol: String) async throws -> Quote {
        try await api.send(MarketEndpoint.quote(symbol: symbol))   // one line, like UserRepository.getPortfolio
    }
}
// Quote: Decodable with CodingKeys mapping c/d/dp/h/l/o/pc/t to readable names (price, change, changePercent, ...)
```

**Done when:** a unit test with a mock `APIClient` returns a decoded `Quote`, and one real call prints a price.
Add search (`MarketEndpoint.search`, `SearchResult`) after the quote works.

**Later upgrades (copy Derayah):** a request interceptor that adds an auth header and, on 401, refreshes the token once for
all waiting requests (see `AuthInterceptor`); log request time and failures; decode the server's error body on non-2xx.

## 5. Networking: WebSocket (milestone M5)

The Derayah shape: a **service** owns **providers**; screens see a stream of events.

```swift
// Networking/Socket/SocketProvider.swift
public enum SocketEvent: Sendable {
    case state(ConnectionState)
    case message(channel: String, data: Data)
    case error(String)
}
public enum ConnectionState: Sendable { case disconnected, connecting, connected }

public protocol SocketProvider: Sendable {
    var events: AsyncStream<SocketEvent> { get }
    func connect() async throws
    func disconnect() async
    func subscribe(symbols: [String]) async throws
    func unsubscribe(symbols: [String]) async throws
}
```

```swift
// Networking/Socket/FinnhubProvider.swift  (URLSessionWebSocketTask, no library)
public actor FinnhubProvider: SocketProvider {
    public nonisolated let events: AsyncStream<SocketEvent>
    private let continuation: AsyncStream<SocketEvent>.Continuation
    private let apiKey: String                     // injected by the app, never read from the bundle here
    private var task: URLSessionWebSocketTask?
    private var symbols: Set<String> = []          // kept so we can resubscribe after reconnect

    public init(apiKey: String) {
        self.apiKey = apiKey
        (events, continuation) = AsyncStream.makeStream()
    }

    public func connect() async throws {
        guard task == nil else { return }          // already connected or connecting
        continuation.yield(.state(.connecting))
        var comps = URLComponents(string: "wss://ws.finnhub.io")!
        comps.queryItems = [.init(name: "token", value: apiKey)]
        let task = URLSession.shared.webSocketTask(with: comps.url!)
        self.task = task
        task.resume()
        continuation.yield(.state(.connected))
        Task { await receiveLoop(task) }
        if !symbols.isEmpty { try await subscribe(symbols: Array(symbols)) }   // replay
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while let message = try? await task.receive() {
            if case .string(let text) = message { continuation.yield(.message(channel: "trade", data: Data(text.utf8))) }
        }
        self.task = nil
        continuation.yield(.state(.disconnected))  // the service decides whether to reconnect
    }

    public func subscribe(symbols new: [String]) async throws {
        symbols.formUnion(new)
        for symbol in new {                        // Finnhub takes one symbol per subscribe message
            let payload = ["type": "subscribe", "symbol": symbol]
            let data = try JSONSerialization.data(withJSONObject: payload)
            try await task?.send(.string(String(decoding: data, as: UTF8.self)))
        }
    }
    // unsubscribe: same with "type": "unsubscribe"; disconnect: task?.cancel(with: .goingAway, reason: nil); task = nil
}
```

```swift
// SocketService: the facade screens use (Derayah: DerayahSocketManager + SocketService)
public actor SocketService {
    private let provider: SocketProvider
    public init(provider: SocketProvider) { self.provider = provider }
    public var events: AsyncStream<SocketEvent> { provider.events }

    /// Connect first, then subscribe. Subscribing to a dead connection must never silently drop.
    public func subscribe(_ symbols: [String]) async throws {
        try await provider.connect()
        try await provider.subscribe(symbols: symbols)
    }
}
```

Parse the message into domain `PriceTick`s (symbol, price, time) in the Domain layer, not in the view.
One Finnhub message can hold several trades in its `data` array, and it may also send non-trade messages (for example pings).
So `PriceTick.decode(_ data: Data) -> [PriceTick]` returns an array, empty for anything that is not a trade.

**Lifecycle rules learned from Derayah (build each one):**
1. **Connect lazily and coalesce.** Two screens calling connect at once must share one attempt (Derayah keeps an in-flight `Task`).
2. **Keep subscriptions** so a reconnect replays them.
3. **Background:** on `scenePhase == .background`, disconnect but keep the subscription set. On `.active`, reconnect with retry/backoff (0s, 2s, 5s).
4. **Cleanup:** a screen stops listening when it disappears (`.task` cancels automatically).
5. **Surface connection state** (banner "reconnecting…") instead of silently showing stale prices.
6. **Market closed is not an error.** A connected socket with no ticks after hours is normal. Show the last quote and a "market closed" hint.

**Done when:** AAPL and MSFT rows update live while the US market is open; backgrounding and returning restores ticks without a relaunch.

## 6. Dependency injection (milestone M3)

Use [Factory](https://github.com/hmlongco/Factory) (the SPM package Derayah uses). Add the latest 2.x via Package Manager.

```swift
// DI/Container+Registrations.swift
extension Container {
    var apiClient: Factory<APIClient> {
        self { URLSessionAPIClient(defaultHeaders: ["X-Finnhub-Token": AppConfig.finnhubKey]) }.singleton
    }
    var marketRepo: Factory<MarketRepository> { self { LiveMarketRepository(api: self.apiClient()) } }
    var socketService: Factory<SocketService> { self { SocketService(provider: FinnhubProvider(apiKey: AppConfig.finnhubKey)) }.singleton }
}
```

In a view model: `@ObservationIgnored @Injected(\.marketRepo) private var repo`.
In tests: `Container.shared.marketRepo.register { MockMarketRepository() }`.

**Gotcha:** `Container.shared` is global. Tests that swap mocks must run **serially**, and each should reset
(`Container.shared.reset()`) in setup, or they leak into each other (Derayah's test schemes are serial for this reason).

## 7. State and view models (milestone M1/M2)

Model every screen's data state explicitly:

```swift
enum ViewState<Value> {
    case loading
    case loaded(Value)
    case error(String)
}
```

```swift
@MainActor @Observable
final class AssetDetailViewModel {
    private(set) var state: ViewState<Quote> = .loading
    private(set) var livePrice: Double?
    @ObservationIgnored @Injected(\.marketRepo) private var repo
    @ObservationIgnored @Injected(\.socketService) private var socket
    let symbol: String
    init(symbol: String) { self.symbol = symbol }

    func load() async {
        state = .loading
        do { state = .loaded(try await repo.quote(symbol: symbol)) }
        catch { state = .error(error.localizedDescription) }
    }
    func listen() async {                       // run from the view's .task; ends when view disappears
        try? await socket.subscribe([symbol])
        for await event in await socket.events {
            if case .message(_, let data) = event,
               let tick = PriceTick.decode(data).last(where: { $0.symbol == symbol }) {
                livePrice = tick.price
            }
        }
    }
}
```

```swift
struct AssetDetailView: View {
    @State private var viewModel: AssetDetailViewModel
    init(symbol: String) { _viewModel = State(initialValue: AssetDetailViewModel(symbol: symbol)) }  // owned by this view
    var body: some View {
        content
            .task { await viewModel.load() }
            .task { await viewModel.listen() }
    }
    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading: ProgressView()
        case .loaded(let t): /* stats + live price */
        case .error(let m): /* message + retry button */
        }
    }
}
```

Which wrapper when:
- `@State` owns an `@Observable` object the view creates. `@Bindable` is for an object passed in (or from the environment) when you need `$` bindings.
- Older Derayah screens use `ObservableObject` + `@StateObject`/`@Published`. Know it, but write new code with `@Observable`.
- `_viewModel = State(initialValue:)` is how you set an `@State` property in `init`.

## 8. Navigation: coordinators (milestone M4)

Derayah pattern: a `Route` enum, a coordinator that maps route → view, and a `NavigationStack(path:)` bound to the coordinator.

```swift
enum WatchlistRoute: Hashable { case asset(symbol: String), settings }

@Observable final class Navigation { var path = NavigationPath() }

@Observable final class WatchlistCoordinator {
    let navigation = Navigation()
    func trigger(_ route: WatchlistRoute) { navigation.path.append(route) }
    @ViewBuilder func buildView(for route: WatchlistRoute) -> some View {
        switch route {
        case .asset(let s): AssetDetailView(symbol: s)
        case .settings: SettingsView()
        }
    }
}
```

```swift
struct WatchlistTab: View {
    @State private var coordinator = WatchlistCoordinator()
    var body: some View {
        NavigationStack(path: $coordinator.navigation.path) {
            WatchlistView(onSelect: { coordinator.trigger(.asset(symbol: $0)) })
                .navigationDestination(for: WatchlistRoute.self) { coordinator.buildView(for: $0) }
        }
    }
}
```

Rules to copy:
- **Pushes** go through `coordinator.trigger(route)`. **Sheets and full-screen covers** are separate view state (`@State var showX` + `.sheet`), not part of the path.
- Derayah hides the system nav bar and draws its own header. Optional: try that in M8 to see the tradeoffs.

## 9. App shell and root switching (milestone M6)

```swift
@main struct TickrApp: App {
    @State private var root = AppRootManager()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            switch root.current {
            case .splash: SplashView()
            case .home:   HomeTabs()
            }
        }
        .environment(root)
        .onChange(of: phase) { _, new in root.handle(scenePhase: new) }   // disconnect/reconnect sockets here
    }
}
```

`AppRootManager` is an `@Observable` holding `current` and owning socket connect/disconnect on scene changes. An
`AppDelegate` via `@UIApplicationDelegateAdaptor` is only needed for SDK setup and push callbacks; skip it until you need those.

## 10. Feature flag and old/new screens (milestone M7)

Practice the Silk Road pattern without a server:

```swift
@Observable final class FeatureFlags {
    var newWatchlistDesign: Bool { didSet { UserDefaults.standard.set(newWatchlistDesign, forKey: "ff_newWatchlist") } }
    init() { newWatchlistDesign = UserDefaults.standard.bool(forKey: "ff_newWatchlist") }
}
```

Build `WatchlistView` (old) and `NewWatchlistView` (new), and pick one with the flag. Add a debug sheet (a toggle in Settings,
or a shake gesture) to flip it. Then try both styles of branching: whole-screen twins, and a small in-view `if`
(for example toast vs full-screen alert).

Also persist the watchlist symbols with `@AppStorage` or `UserDefaults` (use Keychain only for secrets).

## 11. Habits to copy and flaws to avoid

| Copy from Derayah | Avoid |
|---|---|
| Endpoint enum + one-line repository methods | Global singletons (`PortfolioManger.instance`): pass dependencies in instead |
| Explicit loading/loaded/error states | View models of 1,000+ lines: split by responsibility |
| Connect-then-subscribe, replay on reconnect | Duplicated alert modifiers per screen: build one shared presenter |
| Protocols at every boundary, mocks in tests | Callbacks mixed with async/await for the same job: pick `async` |
| Background disconnect + foreground recovery | Skipping tests for new features |
| Coordinators for pushes | Business logic inside views |

## 12. Where each piece lives in the real project

| Your file | Compare with |
|---|---|
| `Endpoint`, `MarketEndpoint` | [AuthenticationEndpoint.swift](InternalPackages/Domain/Sources/Domain/Targets/AuthenticationEndpoint.swift), `DomainCommon/Targets/Replace/BaseNetworkRequest.swift` |
| `URLSessionAPIClient` | [URLSessionAPIClient.swift](InternalPackages/DomainCommon/Repositories/URLSessionAPIClient.swift) (note `AuthInterceptor`) |
| `MarketRepository` | [UserRepository.swift](InternalPackages/Domain/Sources/Domain/Repositories/UserRepository.swift), `BaseRepository.swift` |
| Use case | [GetVirtualIbanAccountsUseCase.swift](DerayahNewUI/Derayah_App/More/AllAccounts/ViewModel/GetVirtualIbanAccountsUseCase.swift) (the only one) |
| View + view model + call | [PendingBenficiaries.swift](DerayahNewUI/Derayah_App/More/Beneficiaries/View/PendingBenficiaries.swift) and `PendingBenficiariesVM.swift` |
| `SocketService`, providers | `InternalPackages/DerayahSocket/` and [BolignUSPricing.swift](DerayahNewUI/Derayah_App/NewMarket/ViewModel/BolignUSPricing.swift) |
| Lifecycle handling | [AppRootManager.swift](DerayahNewUI/Mangers/AppRootManager.swift) |
| Coordinator | `InternalPackages/Routing/Coordinator/`, `WatchlistCoordinator.swift` |
| Watchlist screen + sheets | [WatchlistTabView.swift](DerayahNewUI/Derayah_App/Watchlist/WatchlistTabView.swift) |
| DI registrations | [Extension+Factory.swift](DerayahNewUI/Extensions/Extension+Factory.swift) |
| Feature flag | `Extension+FeatureFlags.swift`, `KYCCoordinator.swift` (old/new twins) |

## 13. Milestones

| # | Build | Skill | Done when |
|---|---|---|---|
| M0 | Project + local package with `Networking`, `Domain` targets, iOS 17 | SPM layering | App builds; App target imports `Domain`, not the reverse |
| M1 | Watchlist list with hardcoded symbols, `ViewState`, `@Observable` VM | State | Loading, loaded and error each reachable; Retry works |
| M2 | REST: endpoint enum, client, repository, quote (price, high, low, change) | Networking | Real data shown; mock-based test passes |
| M3 | Factory DI + mock repository | DI, testing | Test swaps the mock in; tests run serially |
| M4 | Detail screen via coordinator + route enum | Navigation | Back swipe works; route logged |
| M5 | WebSocket: Finnhub provider, service, live price on rows | Sockets | Ticks update while the market is open; reconnect after background works |
| M5b | Optional: `BinanceProvider` as a second `SocketProvider` (crypto, 24/7) | Protocol swap | Ticks flow after market hours; screens unchanged |
| M6 | `AppRootManager`, splash → home, scenePhase handling | App lifecycle | Sockets drop in background and recover |
| M7 | Feature flag with old/new watchlist | Flags | Toggle flips screen without relaunch |
| M8 | Sheets (manage list), custom header, persistence | SwiftUI polish | List survives relaunch |
| M9 | Tests, lint (SwiftLint), README | Quality | `swift test` green |

## 14. Using this file with Claude in the new project

Put this in the new project's `CLAUDE.md` so Claude coaches instead of writing the code for you:

```
I am learning by building this project by hand, following BLUEPRINT.md.
Act as a mentor. Do NOT write feature code unless I ask for it.
When I finish a milestone, review my code against BLUEPRINT.md: layering, state handling, naming, tests.
Point to the exact line and explain why, then let me fix it.
If I'm stuck, give a hint first, then a small snippet only if I ask again.
```

Useful prompts: "Review M2 against the blueprint." · "Why is my view not updating?" · "Quiz me on `@State` vs `@Bindable`." ·
"Compare my SocketService to the real one in the Derayah repo."
