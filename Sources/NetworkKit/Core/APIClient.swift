import Foundation

/// The public surface for performing network requests.
public protocol APIClient: Sendable {
    /// Sends a request and decodes the response into `T`.
    func send<T: Decodable & Sendable>(
        _ endpoint: any Endpoint,
        as type: T.Type
    ) async throws -> NetworkResponse<T>

    /// Sends a request and returns the raw response body.
    func sendRaw(_ endpoint: any Endpoint) async throws -> NetworkResponse<Data>

    /// Uploads a body (typically multipart) and decodes the response into `T`,
    /// reporting progress to `onProgress`.
    func upload<T: Decodable & Sendable>(
        _ endpoint: any Endpoint,
        as type: T.Type,
        onProgress: ProgressHandler?
    ) async throws -> NetworkResponse<T>

    /// Downloads the endpoint's resource to a temporary file URL, reporting
    /// progress to `onProgress`.
    func download(
        _ endpoint: any Endpoint,
        onProgress: ProgressHandler?
    ) async throws -> (url: URL, response: HTTPURLResponse)
}

public extension APIClient {
    /// Convenience overload inferring `T` from context.
    func send<T: Decodable & Sendable>(_ endpoint: any Endpoint) async throws -> T {
        try await send(endpoint, as: T.self).value
    }

    func upload<T: Decodable & Sendable>(_ endpoint: any Endpoint, as type: T.Type) async throws -> NetworkResponse<T> {
        try await upload(endpoint, as: type, onProgress: nil)
    }
}
