//
//  APIService.swift
//  HKNetworkKit+Demo
//
//  Created by Harsh Kadiya on 05/03/25.
//


import Foundation
import HKNetworkKit

// MARK: - Optional: accept any server trust (mirrors the old SSLBypassDelegate)

/// Accepts every server certificate. **Insecure** — only use behind a debugging
/// proxy (e.g. Charles) or for self-signed dev servers, never in production.
struct InsecureServerTrustEvaluator: ServerTrustEvaluator {
    func evaluate(_ trust: SecTrust, forHost host: String) -> Bool { true }
}

// MARK: - APIService

final class APIService {

    static let shared = APIService()

    private let client: APIClient
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - allowInsecureSSL: Bypass certificate validation (default `false`).
    ///     The legacy `APIManager` bypassed SSL; set `true` only if you need
    ///     that behaviour (e.g. a proxy), otherwise leave secure.
    ///   - decoder: JSON decoder used for responses (default: plain decoder,
    ///     matching `APIManager`).
    init(allowInsecureSSL: Bool = false, decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder

        let configuration = NetworkConfiguration(
            // Fallback only — every endpoint supplies its own baseURL.
            baseURL: URL(string: "https://{DOMIN}/PATH")!,
            defaultHeaders: ["Content-Type": "application/json"],
            timeout: 30,
            // Plain coding to match the existing APIManager behaviour.
            coders: .default,
            retryPolicy: DefaultRetryPolicy(
                maxRetryCount: 2,
                strategy: .exponential(base: 0.5, maxDelay: 8)
            ),
            logger: ConsoleLogger(level: .debug, logsCurl: true),
            serverTrustEvaluator: allowInsecureSSL ? InsecureServerTrustEvaluator() : nil,
            reachability: .shared,
            failsWhenUnreachable: true
        )

        self.client = NetworkClient(configuration: configuration)
    }

    // MARK: Async API

    /// Sends a request and decodes the JSON response into `T`.
    @discardableResult
    func request<T: Decodable>(_ endpoint: EndpointProtocol, body: Data? = nil) async throws -> T {
        let data = try await requestData(endpoint, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("\n DECODING ERROR:", error)
            #endif
            throw error
        }
    }

    /// Convenience: encodes an `Encodable` body to JSON, then sends.
    @discardableResult
    func request<T: Decodable, Body: Encodable>(
        _ endpoint: EndpointProtocol,
        body: Body
    ) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(endpoint, body: data)
    }

    /// Sends a request and returns the raw response body.
    func requestData(_ endpoint: EndpointProtocol, body: Data? = nil) async throws -> Data {
        do {
            // `EndpointProtocol` is bridged to a full request inside NetworkKit.
            let response = try await client.sendRaw(endpoint, body: body)
            #if DEBUG
            print("\n API RESPONSE — \(response.statusCode)")
//            prettyPrintJSON(response.data)
            #endif
            return response.data
        } catch let error as APIError {
            if case .unauthorized = error {
                await handleUnauthorized()
            }
            #if DEBUG
            print("\n API ERROR:", error.localizedDescription)
            #endif
            throw error
        }
    }

    // MARK: Completion-based bridge (drop-in for the old APIManager signature)

    func request<T: Codable>(
        _ endpoint: EndpointProtocol,
        body: Data? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            do {
                let value: T = try await request(endpoint, body: body)
                await MainActor.run { completion(.success(value)) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    // MARK: 401 handling (mirrors APIManager)

    @MainActor
    private func handleUnauthorized() {
        AppStorage.shared.remove()
        AppStorage.shared.removeShowVitals()
        AppStorage.shared.token = nil
        makeRootViewController(SplaceVC())
    }
}
