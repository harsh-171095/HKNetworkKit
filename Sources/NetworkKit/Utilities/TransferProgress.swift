import Foundation

/// Progress information for an upload or download.
public struct TransferProgress: Sendable, Hashable {
    public let completedBytes: Int64
    public let totalBytes: Int64

    public init(completedBytes: Int64, totalBytes: Int64) {
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }

    /// Fraction completed in `0...1`, or `nil` when the total is unknown.
    public var fraction: Double? {
        guard totalBytes > 0 else { return nil }
        return Double(completedBytes) / Double(totalBytes)
    }
}

/// A callback invoked with incremental transfer progress.
public typealias ProgressHandler = @Sendable (TransferProgress) -> Void
