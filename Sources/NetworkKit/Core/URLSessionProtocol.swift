import Foundation

/// Abstraction over `URLSession` so the client can be unit-tested with a mock.
///
/// `URLSession` already conforms to this in the conformance below.
public protocol URLSessionProtocol: Sendable {
    /// Performs a data request and returns the decoded data and response.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

    /// Uploads `bodyData` for the given request and returns the response data.
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse)

    /// Downloads the resource at the given request to a temporary file URL.
    func download(for request: URLRequest) async throws -> (URL, URLResponse)
}

extension URLSession: URLSessionProtocol {
    public func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        try await upload(for: request, from: bodyData, delegate: nil)
    }

    public func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        try await download(for: request, delegate: nil)
    }
}
