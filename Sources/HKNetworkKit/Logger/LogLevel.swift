import Foundation

/// Verbosity of the network logger, ordered from least to most verbose.
public enum LogLevel: Int, Sendable, Comparable {
    case none = 0
    case error
    case warning
    case info
    case debug
    case verbose

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
