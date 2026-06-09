import Foundation

/// Observability hooks invoked around each network call. Unlike interceptors,
/// middleware cannot mutate the request — it observes lifecycle events for
/// logging, analytics, and metrics.
public protocol Middleware: Sendable {
    func willSend(_ request: URLRequest, for endpoint: any Endpoint) async
    func didReceive(_ result: Result<(Data, HTTPURLResponse), APIError>, for endpoint: any Endpoint, duration: TimeInterval) async
}

public extension Middleware {
    func willSend(_ request: URLRequest, for endpoint: any Endpoint) async {}
    func didReceive(_ result: Result<(Data, HTTPURLResponse), APIError>, for endpoint: any Endpoint, duration: TimeInterval) async {}
}

/// Captures simple per-request metrics and forwards them to a sink.
public struct MetricsMiddleware: Middleware {
    public struct Metric: Sendable {
        public let path: String
        public let statusCode: Int?
        public let duration: TimeInterval
        public let succeeded: Bool
    }

    private let sink: @Sendable (Metric) -> Void

    public init(sink: @escaping @Sendable (Metric) -> Void) {
        self.sink = sink
    }

    public func didReceive(_ result: Result<(Data, HTTPURLResponse), APIError>, for endpoint: any Endpoint, duration: TimeInterval) async {
        switch result {
        case .success(let (_, response)):
            sink(Metric(path: endpoint.path, statusCode: response.statusCode, duration: duration, succeeded: true))
        case .failure(let error):
            sink(Metric(path: endpoint.path, statusCode: error.statusCode, duration: duration, succeeded: false))
        }
    }
}
