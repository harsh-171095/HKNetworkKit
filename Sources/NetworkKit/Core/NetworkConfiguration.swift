import Foundation

/// Immutable configuration for an ``APIClient``. Build one with the designated
/// initializer or tweak ``default(baseURL:)``.
public struct NetworkConfiguration: Sendable {
    /// The default base URL used when an endpoint does not provide its own.
    public let baseURL: URL
    /// Headers applied to every request before interceptors run.
    public let defaultHeaders: HTTPHeaders
    /// Default request timeout, in seconds.
    public let timeout: TimeInterval
    /// JSON encoder/decoder pairing.
    public let coders: CoderConfiguration
    /// Response status-code validation.
    public let validator: ResponseValidator
    /// Retry policy applied to failed requests.
    public let retryPolicy: RetryPolicy
    /// Logger.
    public let logger: NetworkLogger
    /// Authentication provider, if any.
    public let authenticationProvider: AuthenticationProvider?
    /// Request interceptors, run in order.
    public let interceptors: [RequestInterceptor]
    /// Observability middleware.
    public let middlewares: [Middleware]
    /// Server trust evaluator for SSL/certificate pinning.
    public let serverTrustEvaluator: ServerTrustEvaluator?
    /// Whether to reject non-HTTPS URLs.
    public let enforcesHTTPS: Bool
    /// Optional reachability monitor used to fail fast when offline.
    public let reachability: NetworkReachability?
    /// When `true` and `reachability` reports no connection, requests fail
    /// immediately with `APIError.network` instead of hitting the transport.
    public let failsWhenUnreachable: Bool

    public init(
        baseURL: URL,
        defaultHeaders: HTTPHeaders = [:],
        timeout: TimeInterval = 30,
        coders: CoderConfiguration = .default,
        validator: ResponseValidator = DefaultResponseValidator(),
        retryPolicy: RetryPolicy = DefaultRetryPolicy(),
        logger: NetworkLogger = ConsoleLogger(level: .info),
        authenticationProvider: AuthenticationProvider? = nil,
        interceptors: [RequestInterceptor] = [],
        middlewares: [Middleware] = [],
        serverTrustEvaluator: ServerTrustEvaluator? = nil,
        enforcesHTTPS: Bool = true,
        reachability: NetworkReachability? = nil,
        failsWhenUnreachable: Bool = false
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeout = timeout
        self.coders = coders
        self.validator = validator
        self.retryPolicy = retryPolicy
        self.logger = logger
        self.authenticationProvider = authenticationProvider
        self.interceptors = interceptors
        self.middlewares = middlewares
        self.serverTrustEvaluator = serverTrustEvaluator
        self.enforcesHTTPS = enforcesHTTPS
        self.reachability = reachability
        self.failsWhenUnreachable = failsWhenUnreachable
    }

    public static func `default`(baseURL: URL) -> NetworkConfiguration {
        NetworkConfiguration(baseURL: baseURL)
    }
}
