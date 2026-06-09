import Foundation

/// Decides whether and when a failed request should be retried.
public protocol RetryPolicy: Sendable {
    /// Returns the delay before the next attempt, or `nil` to stop retrying.
    ///
    /// - Parameters:
    ///   - error: The error produced by the failed attempt.
    ///   - attempt: The zero-based index of the attempt that just failed.
    func retryDelay(for error: APIError, attempt: Int) -> TimeInterval?
}

/// The backoff strategy used by `DefaultRetryPolicy`.
public enum BackoffStrategy: Sendable {
    /// A constant delay between attempts.
    case fixed(TimeInterval)
    /// Exponential growth: `base * 2^attempt`, capped at `maxDelay`.
    case exponential(base: TimeInterval, maxDelay: TimeInterval)

    func delay(forAttempt attempt: Int) -> TimeInterval {
        switch self {
        case .fixed(let delay):
            return delay
        case .exponential(let base, let maxDelay):
            return min(base * pow(2, Double(attempt)), maxDelay)
        }
    }
}

/// A configurable retry policy.
public struct DefaultRetryPolicy: RetryPolicy {
    public let maxRetryCount: Int
    public let strategy: BackoffStrategy
    /// Status codes that should trigger a retry.
    public let retryableStatusCodes: Set<Int>
    /// Whether transport-level network errors should be retried.
    public let retriesNetworkErrors: Bool

    public init(
        maxRetryCount: Int = 2,
        strategy: BackoffStrategy = .exponential(base: 0.5, maxDelay: 8),
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        retriesNetworkErrors: Bool = true
    ) {
        self.maxRetryCount = maxRetryCount
        self.strategy = strategy
        self.retryableStatusCodes = retryableStatusCodes
        self.retriesNetworkErrors = retriesNetworkErrors
    }

    public func retryDelay(for error: APIError, attempt: Int) -> TimeInterval? {
        guard attempt < maxRetryCount else { return nil }

        switch error {
        case .cancelled:
            return nil
        case .timeout:
            return strategy.delay(forAttempt: attempt)
        case .network where retriesNetworkErrors:
            return strategy.delay(forAttempt: attempt)
        case .rateLimited(let retryAfter, _):
            return retryAfter ?? strategy.delay(forAttempt: attempt)
        default:
            if let code = error.statusCode, retryableStatusCodes.contains(code) {
                return strategy.delay(forAttempt: attempt)
            }
            return nil
        }
    }
}

/// A policy that never retries.
public struct NoRetryPolicy: RetryPolicy {
    public init() {}
    public func retryDelay(for error: APIError, attempt: Int) -> TimeInterval? { nil }
}
