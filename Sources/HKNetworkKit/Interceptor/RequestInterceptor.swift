import Foundation

/// Intercepts requests before they are sent and responses after they return.
///
/// Interceptors run in registration order on the way out, and in reverse on the
/// way back — much like Alamofire's `RequestInterceptor`.
public protocol RequestInterceptor: Sendable {
    /// Adapts an outgoing request, e.g. to add dynamic headers or sign it.
    func adapt(_ request: URLRequest, for endpoint: any Endpoint) async throws -> URLRequest

    /// Inspects a completed response. Throw to convert a success into a failure.
    func process(data: Data, response: HTTPURLResponse, for endpoint: any Endpoint) async throws
}

public extension RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: any Endpoint) async throws -> URLRequest { request }
    func process(data: Data, response: HTTPURLResponse, for endpoint: any Endpoint) async throws {}
}

/// Adds a fixed set of headers to every request.
public struct HeaderInjectionInterceptor: RequestInterceptor {
    private let headers: HTTPHeaders

    public init(headers: HTTPHeaders) {
        self.headers = headers
    }

    public func adapt(_ request: URLRequest, for endpoint: any Endpoint) async throws -> URLRequest {
        var request = request
        for (key, value) in headers.dictionary {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

/// Signs each request with an HMAC-style signature header produced by `signer`.
public struct RequestSigningInterceptor: RequestInterceptor {
    private let headerField: String
    private let signer: @Sendable (URLRequest) -> String

    public init(headerField: String = "X-Signature", signer: @escaping @Sendable (URLRequest) -> String) {
        self.headerField = headerField
        self.signer = signer
    }

    public func adapt(_ request: URLRequest, for endpoint: any Endpoint) async throws -> URLRequest {
        var request = request
        request.setValue(signer(request), forHTTPHeaderField: headerField)
        return request
    }
}
