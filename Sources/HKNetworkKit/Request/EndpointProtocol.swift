import Foundation

/// A lightweight, **string-based** way to declare endpoints — the fastest way to
/// adopt HKNetworkKit in an existing app. Conform an `enum` to it and pass the
/// cases straight to `APIClient.send(_:body:as:)`; HKNetworkKit converts them into
/// full ``Endpoint`` requests for you (splitting any `?query` out of the path,
/// mapping the method string to ``HTTPMethod``, etc.).
///
/// ```swift
/// enum AppEndpoint: EndpointProtocol {
///     case login, getProfile, scans(page: Int)
///
///     var baseURL: String { "https://api.example.com" }
///     var endpoint: String {
///         switch self {
///         case .login:          return "/auth/login"
///         case .getProfile:     return "/me"
///         case .scans(let p):   return "/scans?page=\(p)"
///         }
///     }
///     var method: String { self == .login ? "POST" : "GET" }
/// }
///
/// // Usage — no adapter needed:
/// let user: User = try await client.send(AppEndpoint.getProfile)
/// let created: User = try await client.send(AppEndpoint.login, body: jsonData)
/// ```
///
/// For full control (typed methods, multipart bodies, per-request cache/timeout),
/// conform to ``Endpoint`` instead.
public protocol EndpointProtocol {
    /// Scheme + host (and optional base path), e.g. `"https://api.example.com/v1"`.
    var baseURL: String { get }
    /// The path, which may include a `?query` string, e.g. `"/users?page=1"`.
    var endpoint: String { get }
    /// HTTP method as a string, e.g. `"GET"`, `"POST"`. Defaults to `"GET"`.
    var method: String { get }
    /// Header fields applied to the request. Defaults to empty.
    var headers: [String: String] { get }
}

public extension EndpointProtocol {
    var method: String { "GET" }
    var headers: [String: String] { [:] }
}

/// Adapts an ``EndpointProtocol`` value into a full ``Endpoint``. Internal — apps
/// use the `APIClient` convenience methods below and never touch this directly.
struct BridgedEndpoint: Endpoint {
    let baseURL: URL?
    let path: String
    let method: HTTPMethod
    let headers: HTTPHeaders
    let queryItems: [URLQueryItem]
    let body: RequestBody
    // Auth is expected to be supplied via `headers`, so HKNetworkKit's own
    // authentication layer is left disabled for bridged endpoints.
    let requiresAuthentication = false

    init(_ endpoint: EndpointProtocol, body: RequestBody = .none) {
        self.baseURL = URL(string: endpoint.baseURL)
        self.method = HTTPMethod(rawValue: endpoint.method.uppercased()) ?? .get
        self.headers = HTTPHeaders(endpoint.headers)
        self.body = body

        // `endpoint.endpoint` may already contain a query string ("/x?a=b").
        let raw = endpoint.endpoint
        if let separator = raw.firstIndex(of: "?") {
            self.path = String(raw[..<separator])
            let query = String(raw[raw.index(after: separator)...])
            self.queryItems = URLComponents(string: "?\(query)")?.queryItems ?? []
        } else {
            self.path = raw
            self.queryItems = []
        }
    }
}

// MARK: - APIClient convenience for EndpointProtocol

public extension APIClient {

    /// Sends a string-based ``EndpointProtocol`` and decodes the response into `T`.
    func send<T: Decodable & Sendable>(
        _ endpoint: EndpointProtocol,
        body: Data? = nil,
        as type: T.Type
    ) async throws -> NetworkResponse<T> {
        try await send(BridgedEndpoint(endpoint, body: body.map(RequestBody.data) ?? .none), as: type)
    }

    /// Sends a string-based ``EndpointProtocol`` and returns the decoded value.
    func send<T: Decodable & Sendable>(
        _ endpoint: EndpointProtocol,
        body: Data? = nil
    ) async throws -> T {
        try await send(endpoint, body: body, as: T.self).value
    }

    /// Sends a string-based ``EndpointProtocol`` and returns the raw response body.
    func sendRaw(
        _ endpoint: EndpointProtocol,
        body: Data? = nil
    ) async throws -> NetworkResponse<Data> {
        try await sendRaw(BridgedEndpoint(endpoint, body: body.map(RequestBody.data) ?? .none))
    }
}
