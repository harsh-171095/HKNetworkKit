import Foundation

/// The comprehensive error type surfaced by all NetworkKit operations.
public enum APIError: Error, Sendable {
    /// The endpoint produced an invalid or malformed URL.
    case invalidURL(String)
    /// A transport-level failure (no connectivity, DNS failure, etc.).
    case network(underlying: URLError)
    /// The request exceeded its configured timeout.
    case timeout
    /// A TLS / certificate validation failure (including SSL pinning failures).
    case ssl(reason: String)
    /// The response body could not be decoded into the expected type.
    case decoding(underlying: Error)
    /// The request body could not be encoded.
    case encoding(underlying: Error)
    /// The server returned a 5xx status code.
    case server(statusCode: Int, data: Data?)
    /// 401 — authentication is required or the supplied credentials are invalid.
    case unauthorized(data: Data?)
    /// 403 — the credentials are valid but lack permission.
    case forbidden(data: Data?)
    /// 404 — the resource does not exist.
    case notFound(data: Data?)
    /// 429 — too many requests. `retryAfter` is the server-suggested delay, if any.
    case rateLimited(retryAfter: TimeInterval?, data: Data?)
    /// The response status code was unexpected and not otherwise classified.
    case unacceptableStatusCode(statusCode: Int, data: Data?)
    /// The request was cancelled.
    case cancelled
    /// Any other, unclassified failure.
    case unknown(underlying: Error?)

    /// The HTTP status code associated with the error, when applicable.
    public var statusCode: Int? {
        switch self {
        case .server(let code, _): return code
        case .unauthorized: return 401
        case .forbidden: return 403
        case .notFound: return 404
        case .rateLimited: return 429
        case .unacceptableStatusCode(let code, _): return code
        default: return nil
        }
    }

    /// The raw response body associated with the error, when available.
    public var responseData: Data? {
        switch self {
        case .server(_, let data),
             .unauthorized(let data),
             .forbidden(let data),
             .notFound(let data),
             .rateLimited(_, let data),
             .unacceptableStatusCode(_, let data):
            return data
        default:
            return nil
        }
    }

    /// Maps a low-level error into the appropriate `APIError`.
    static func map(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                return .cancelled
            case .timedOut:
                return .timeout
            case .serverCertificateUntrusted,
                 .secureConnectionFailed,
                 .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot,
                 .clientCertificateRejected:
                return .ssl(reason: urlError.localizedDescription)
            default:
                return .network(underlying: urlError)
            }
        }
        return .unknown(underlying: error)
    }
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .timeout:
            return "The request timed out."
        case .ssl(let reason):
            return "SSL/TLS error: \(reason)"
        case .decoding(let underlying):
            return "Failed to decode response: \(underlying.localizedDescription)"
        case .encoding(let underlying):
            return "Failed to encode request: \(underlying.localizedDescription)"
        case .server(let code, _):
            return "Server error (\(code))."
        case .unauthorized:
            return "Unauthorized (401)."
        case .forbidden:
            return "Forbidden (403)."
        case .notFound:
            return "Not found (404)."
        case .rateLimited(let retryAfter, _):
            if let retryAfter {
                return "Rate limited (429). Retry after \(retryAfter)s."
            }
            return "Rate limited (429)."
        case .unacceptableStatusCode(let code, _):
            return "Unacceptable status code: \(code)."
        case .cancelled:
            return "The request was cancelled."
        case .unknown(let underlying):
            return "Unknown error: \(underlying?.localizedDescription ?? "n/a")"
        }
    }
}
