import Foundation
import os

/// A pluggable logger. Provide your own conformance to forward logs to your
/// analytics or logging backend.
public protocol NetworkLogger: Sendable {
    var level: LogLevel { get }
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: HTTPURLResponse?, data: Data?, duration: TimeInterval, error: Error?)
    func log(_ message: String, level: LogLevel)
}

public extension NetworkLogger {
    func log(_ message: String, level: LogLevel) {
        guard level <= self.level, level != .none else { return }
        ConsoleLogger.osLog("\(message)", level: level)
    }
}

/// The default console logger built on `os.Logger`.
public struct ConsoleLogger: NetworkLogger {
    public let level: LogLevel
    /// Whether to print an equivalent `curl` command for each request.
    public let logsCurl: Bool

    public init(level: LogLevel = .info, logsCurl: Bool = false) {
        self.level = level
        self.logsCurl = logsCurl
    }

    public func logRequest(_ request: URLRequest) {
        guard level >= .info else { return }
        var lines = ["➡️ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")"]
        if level >= .debug {
            for (key, value) in request.allHTTPHeaderFields ?? [:] {
                lines.append("  \(key): \(redact(key: key, value: value))")
            }
            if let body = request.httpBody, let string = String(data: body, encoding: .utf8) {
                lines.append("  body: \(string)")
            }
            if logsCurl {
                lines.append(CurlBuilder.build(from: request))
            }
        }
        ConsoleLogger.osLog(lines.joined(separator: "\n"), level: .info)
    }

    public func logResponse(_ response: HTTPURLResponse?, data: Data?, duration: TimeInterval, error: Error?) {
        if let error {
            guard level >= .error else { return }
            ConsoleLogger.osLog("❌ \(error.localizedDescription) (\(String(format: "%.3f", duration))s)", level: .error)
            return
        }
        guard level >= .info else { return }
        let code = response?.statusCode ?? -1
        var lines = ["⬅️ \(code) \(response?.url?.absoluteString ?? "?") (\(String(format: "%.3f", duration))s)"]
        if level >= .verbose, let data, let string = String(data: data, encoding: .utf8) {
            lines.append("  body: \(string)")
        }
        ConsoleLogger.osLog(lines.joined(separator: "\n"), level: .info)
    }

    private func redact(key: String, value: String) -> String {
        if key.lowercased() == "authorization" { return "<redacted>" }
        return value
    }

    static func osLog(_ message: String, level: LogLevel) {
        let logger = os.Logger(subsystem: "NetworkKit", category: "network")
        switch level {
        case .error: logger.error("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .none: break
        default: logger.log("\(message, privacy: .public)")
        }
    }
}

/// Builds a copy-pasteable `curl` command from a request, for debugging.
public enum CurlBuilder {
    public static func build(from request: URLRequest) -> String {
        guard let url = request.url else { return "curl" }
        var components = ["curl -i"]
        components.append("-X \(request.httpMethod ?? "GET")")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            components.append("-H \"\(key): \(value)\"")
        }
        if let body = request.httpBody, let string = String(data: body, encoding: .utf8) {
            let escaped = string.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escaped)\"")
        }
        components.append("\"\(url.absoluteString)\"")
        return components.joined(separator: " ")
    }
}
