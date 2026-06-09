import Foundation

/// Caching behaviour for a request. Maps onto `URLRequest.CachePolicy` plus an
/// expiration hint used by HKNetworkKit's in-memory/disk layers.
public enum NetworkCachePolicy: Sendable, Hashable {
    /// Use the protocol's default caching (`.useProtocolCachePolicy`).
    case `default`
    /// Always ignore caches and hit the network.
    case reloadIgnoringCache
    /// Return cached data if available, otherwise load from the network.
    case returnCacheElseLoad
    /// Use cached data only; fail if absent.
    case cacheOnly
    /// Cache the response in memory/disk for at most `expiry` seconds.
    case expires(after: TimeInterval)

    var urlRequestPolicy: URLRequest.CachePolicy {
        switch self {
        case .default, .expires:
            return .useProtocolCachePolicy
        case .reloadIgnoringCache:
            return .reloadIgnoringLocalCacheData
        case .returnCacheElseLoad:
            return .returnCacheDataElseLoad
        case .cacheOnly:
            return .returnCacheDataDontLoad
        }
    }
}
