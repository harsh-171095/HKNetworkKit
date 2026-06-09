import Foundation

/// Describes a single API endpoint. Conform a type (typically an `enum`) to this
/// protocol to declaratively define your API surface.
///
/// Only `path` and `method` are required; everything else has a sensible default.
public protocol Endpoint: Sendable {
    /// The base URL. When `nil`, the client's configured `baseURL` is used.
    var baseURL: URL? { get }
    /// The path appended to the base URL, e.g. `"/users/profile"`.
    var path: String { get }
    /// The HTTP method.
    var method: HTTPMethod { get }
    /// Static header fields for this endpoint.
    var headers: HTTPHeaders { get }
    /// Query items appended to the URL.
    var queryItems: [URLQueryItem] { get }
    /// The request body.
    var body: RequestBody { get }
    /// A per-request timeout override. When `nil`, the client default is used.
    var timeout: TimeInterval? { get }
    /// The caching policy for this request.
    var cachePolicy: NetworkCachePolicy { get }
    /// Whether this endpoint requires authentication credentials to be attached.
    var requiresAuthentication: Bool { get }
    /// The `Content-Type` header. When `nil` it is inferred from `body`.
    var contentType: String? { get }
    /// The `Accept` header. Defaults to `application/json`.
    var accept: String? { get }
}

// MARK: - Defaults

public extension Endpoint {
    var baseURL: URL? { nil }
    var method: HTTPMethod { .get }
    var headers: HTTPHeaders { [:] }
    var queryItems: [URLQueryItem] { [] }
    var body: RequestBody { .none }
    var timeout: TimeInterval? { nil }
    var cachePolicy: NetworkCachePolicy { .default }
    var requiresAuthentication: Bool { true }
    var contentType: String? { nil }
    var accept: String? { ContentType.json }
}
