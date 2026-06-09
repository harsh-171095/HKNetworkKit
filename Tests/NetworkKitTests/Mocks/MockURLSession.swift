import Foundation
@testable import NetworkKit

/// A scriptable `URLSessionProtocol` for unit tests.
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    struct Stub {
        var data: Data
        var statusCode: Int
        var headers: [String: String]
        var error: Error?

        init(data: Data = Data(), statusCode: Int = 200, headers: [String: String] = [:], error: Error? = nil) {
            self.data = data
            self.statusCode = statusCode
            self.headers = headers
            self.error = error
        }
    }

    private let lock = NSLock()
    private var _stubs: [Stub] = []
    private var _recordedRequests: [URLRequest] = []

    var recordedRequests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _recordedRequests
    }

    /// Enqueue a stub. Stubs are dequeued FIFO; the last stub repeats.
    func enqueue(_ stub: Stub) {
        lock.lock(); defer { lock.unlock() }
        _stubs.append(stub)
    }

    private func nextStub(for request: URLRequest) throws -> (Data, URLResponse) {
        lock.lock(); defer { lock.unlock() }
        _recordedRequests.append(request)

        let stub: Stub
        if _stubs.count > 1 {
            stub = _stubs.removeFirst()
        } else {
            stub = _stubs.first ?? Stub()
        }

        if let error = stub.error { throw error }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        return (stub.data, response)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try nextStub(for: request)
    }

    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        var request = request
        request.httpBody = bodyData
        return try nextStub(for: request)
    }

    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        let (data, response) = try nextStub(for: request)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        return (url, response)
    }
}
