import Foundation

/// Supplies and refreshes credentials for authenticated requests.
///
/// Implementations are `actor`s or otherwise thread-safe, since the client may
/// invoke them concurrently.
public protocol AuthenticationProvider: Sendable {
    /// Applies credentials to an outgoing request.
    func authenticate(_ request: inout URLRequest) async throws

    /// Attempts to refresh credentials after a `401`. Returns `true` if refresh
    /// succeeded and the request should be retried, `false` otherwise.
    func refresh() async throws -> Bool
}

public extension AuthenticationProvider {
    func refresh() async throws -> Bool { false }
}

// MARK: - Bearer Token

/// Attaches a static or dynamically-refreshed bearer token.
public actor BearerTokenProvider: AuthenticationProvider {
    private var token: String?
    private let refreshHandler: (@Sendable () async throws -> String?)?

    public init(token: String? = nil, refreshHandler: (@Sendable () async throws -> String?)? = nil) {
        self.token = token
        self.refreshHandler = refreshHandler
    }

    public func setToken(_ token: String?) {
        self.token = token
    }

    public func authenticate(_ request: inout URLRequest) async throws {
        guard let token else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: HeaderField.authorization)
    }

    public func refresh() async throws -> Bool {
        guard let refreshHandler else { return false }
        let newToken = try await refreshHandler()
        self.token = newToken
        return newToken != nil
    }
}

// MARK: - Basic Auth

/// Attaches HTTP Basic credentials.
public struct BasicAuthProvider: AuthenticationProvider {
    private let header: String

    public init(username: String, password: String) {
        let raw = "\(username):\(password)"
        let encoded = Data(raw.utf8).base64EncodedString()
        self.header = "Basic \(encoded)"
    }

    public func authenticate(_ request: inout URLRequest) async throws {
        request.setValue(header, forHTTPHeaderField: HeaderField.authorization)
    }
}

// MARK: - API Key

/// Attaches an API key to a header (default) or query parameter.
public struct APIKeyProvider: AuthenticationProvider {
    public enum Location: Sendable {
        case header(String)
        case query(String)
    }

    private let key: String
    private let location: Location

    public init(key: String, location: Location = .header(HeaderField.apiKey)) {
        self.key = key
        self.location = location
    }

    public func authenticate(_ request: inout URLRequest) async throws {
        switch location {
        case .header(let field):
            request.setValue(key, forHTTPHeaderField: field)
        case .query(let name):
            guard let url = request.url,
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: name, value: key))
            components.queryItems = items
            request.url = components.url
        }
    }
}
