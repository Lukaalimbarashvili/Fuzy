import Foundation

/// Values injected at build time from `Secrets.xcconfig` (git-ignored) via Info.plist.
nonisolated enum Secrets {
    static var finnhubKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "FinnhubAPIKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else {
            assertionFailure("FinnhubAPIKey missing. Copy Secrets.xcconfig.example to Secrets.xcconfig and attach it to the Debug/Release configurations.")
            return ""
        }
        return key
    }
}

