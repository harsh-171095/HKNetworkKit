import Foundation

/// The default `APIClient` implementation backed by `URLSession`.
///
/// Construct it with a `NetworkConfiguration`. The underlying session is created
/// from the configuration (including SSL pinning) unless one is injected for
/// testing.
public final class NetworkClient: APIClient, @unchecked Sendable {
    private let configuration: NetworkConfiguration
    private let session: URLSessionProtocol
    private let builder: URLRequestBuilder
    /// Concrete session used for progress-reporting transfers (created lazily).
    private let progressSessionConfiguration: URLSessionConfiguration

    /// Designated initializer.
    /// - Parameters:
    ///   - configuration: Client configuration.
    ///   - session: Override the transport, primarily for unit testing. When
    ///     `nil`, a session honouring the configuration's pinning is created.
    public init(configuration: NetworkConfiguration, session: URLSessionProtocol? = nil) {
        self.configuration = configuration
        self.builder = URLRequestBuilder(configuration: configuration)
        self.progressSessionConfiguration = .default

        if let session {
            self.session = session
        } else {
            let delegate = SecuritySessionDelegate(evaluator: configuration.serverTrustEvaluator)
            self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        }
    }

    // MARK: - Public API

    public func send<T: Decodable & Sendable>(
        _ endpoint: any Endpoint,
        as type: T.Type
    ) async throws -> NetworkResponse<T> {
        let (data, response) = try await perform(endpoint) { request in
            try await self.session.data(for: request)
        }
        let value = try data.decoded(as: T.self, using: configuration.coders.decoder)
        return NetworkResponse(value: value, data: data, httpResponse: response)
    }

    public func sendRaw(_ endpoint: any Endpoint) async throws -> NetworkResponse<Data> {
        let (data, response) = try await perform(endpoint) { request in
            try await self.session.data(for: request)
        }
        return NetworkResponse(value: data, data: data, httpResponse: response)
    }

    public func upload<T: Decodable & Sendable>(
        _ endpoint: any Endpoint,
        as type: T.Type,
        onProgress: ProgressHandler?
    ) async throws -> NetworkResponse<T> {
        let (data, response) = try await perform(endpoint) { request in
            let body = request.httpBody ?? Data()
            if let onProgress {
                let delegate = TransferDelegate(evaluator: self.configuration.serverTrustEvaluator, onProgress: onProgress)
                let session = URLSession(configuration: self.progressSessionConfiguration)
                defer { session.finishTasksAndInvalidate() }
                var uploadRequest = request
                uploadRequest.httpBody = nil
                return try await session.upload(for: uploadRequest, from: body, delegate: delegate)
            } else {
                var uploadRequest = request
                uploadRequest.httpBody = nil
                return try await self.session.upload(for: uploadRequest, from: body)
            }
        }
        let value = try data.decoded(as: T.self, using: configuration.coders.decoder)
        return NetworkResponse(value: value, data: data, httpResponse: response)
    }

    public func download(
        _ endpoint: any Endpoint,
        onProgress: ProgressHandler?
    ) async throws -> (url: URL, response: HTTPURLResponse) {
        try checkReachability()
        let request = try await makeAuthenticatedRequest(for: endpoint)
        let start = currentTime()
        do {
            let (url, response): (URL, URLResponse)
            if let onProgress {
                let delegate = TransferDelegate(evaluator: configuration.serverTrustEvaluator, onProgress: onProgress)
                let session = URLSession(configuration: progressSessionConfiguration)
                defer { session.finishTasksAndInvalidate() }
                (url, response) = try await session.download(for: request, delegate: delegate)
            } else {
                (url, response) = try await session.download(for: request)
            }
            guard let http = response as? HTTPURLResponse else {
                throw APIError.unknown(underlying: nil)
            }
            try configuration.validator.validate(data: Data(), response: http)
            await notify(.success((Data(), http)), endpoint: endpoint, start: start)
            return (url, http)
        } catch {
            let mapped = APIError.map(error)
            await notify(.failure(mapped), endpoint: endpoint, start: start)
            throw mapped
        }
    }

    // MARK: - Core request pipeline

    private func perform(
        _ endpoint: any Endpoint,
        transport: @Sendable @escaping (URLRequest) async throws -> (Data, URLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        try checkReachability()
        var attempt = 0
        var didRefresh = false

        while true {
            try Task.checkCancellation()
            let request = try await makeAuthenticatedRequest(for: endpoint)
            let start = currentTime()

            for middleware in configuration.middlewares {
                await middleware.willSend(request, for: endpoint)
            }
            configuration.logger.logRequest(request)

            do {
                let (data, response) = try await transport(request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.unknown(underlying: nil)
                }

                try configuration.validator.validate(data: data, response: http)
                for interceptor in configuration.interceptors {
                    try await interceptor.process(data: data, response: http, for: endpoint)
                }

                configuration.logger.logResponse(http, data: data, duration: currentTime() - start, error: nil)
                await notify(.success((data, http)), endpoint: endpoint, start: start)
                return (data, http)
            } catch {
                let apiError = APIError.map(error)
                configuration.logger.logResponse(nil, data: nil, duration: currentTime() - start, error: apiError)
                await notify(.failure(apiError), endpoint: endpoint, start: start)

                // Attempt a single token refresh on 401.
                if case .unauthorized = apiError,
                   endpoint.requiresAuthentication,
                   !didRefresh,
                   let provider = configuration.authenticationProvider,
                   try await provider.refresh() {
                    didRefresh = true
                    continue
                }

                // Otherwise consult the retry policy.
                if let delay = configuration.retryPolicy.retryDelay(for: apiError, attempt: attempt) {
                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                throw apiError
            }
        }
    }

    private func makeAuthenticatedRequest(for endpoint: any Endpoint) async throws -> URLRequest {
        var request = try builder.makeRequest(for: endpoint)

        if endpoint.requiresAuthentication, let provider = configuration.authenticationProvider {
            try await provider.authenticate(&request)
        }
        for interceptor in configuration.interceptors {
            request = try await interceptor.adapt(request, for: endpoint)
        }
        return request
    }

    private func notify(
        _ result: Result<(Data, HTTPURLResponse), APIError>,
        endpoint: any Endpoint,
        start: TimeInterval
    ) async {
        let duration = currentTime() - start
        for middleware in configuration.middlewares {
            await middleware.didReceive(result, for: endpoint, duration: duration)
        }
    }

    /// Throws `APIError.network` when connectivity gating is enabled and offline.
    private func checkReachability() throws {
        guard configuration.failsWhenUnreachable,
              let reachability = configuration.reachability,
              !reachability.isConnected else {
            return
        }
        throw APIError.network(underlying: URLError(.notConnectedToInternet))
    }

    private func currentTime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
