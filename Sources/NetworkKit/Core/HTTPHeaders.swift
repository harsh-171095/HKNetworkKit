import Foundation

/// A case-insensitive, order-preserving collection of HTTP header fields.
public struct HTTPHeaders: Sendable, Hashable, ExpressibleByDictionaryLiteral {
    private var storage: [String: String]

    public init() {
        storage = [:]
    }

    public init(_ headers: [String: String]) {
        storage = [:]
        for (name, value) in headers {
            storage[name.lowercased()] = value
        }
    }

    public init(dictionaryLiteral elements: (String, String)...) {
        storage = [:]
        for (name, value) in elements {
            storage[name.lowercased()] = value
        }
    }

    /// Adds or replaces a header field.
    public mutating func set(_ value: String, for name: String) {
        storage[name.lowercased()] = value
    }

    /// Removes a header field if present.
    public mutating func remove(_ name: String) {
        storage[name.lowercased()] = nil
    }

    /// Returns the value for a header field, if present.
    public func value(for name: String) -> String? {
        storage[name.lowercased()]
    }

    public subscript(_ name: String) -> String? {
        get { value(for: name) }
        set {
            if let newValue {
                set(newValue, for: name)
            } else {
                remove(name)
            }
        }
    }

    /// Merges another set of headers into this one. Values in `other` win on conflict.
    public mutating func merge(_ other: HTTPHeaders) {
        for (name, value) in other.storage {
            storage[name] = value
        }
    }

    /// A plain dictionary representation suitable for `URLRequest.allHTTPHeaderFields`.
    public var dictionary: [String: String] {
        storage
    }
}

/// Well-known header field names.
public enum HeaderField {
    public static let authorization = "Authorization"
    public static let contentType = "Content-Type"
    public static let accept = "Accept"
    public static let acceptEncoding = "Accept-Encoding"
    public static let userAgent = "User-Agent"
    public static let apiKey = "X-API-Key"
}

/// Well-known MIME types.
public enum ContentType {
    public static let json = "application/json"
    public static let formURLEncoded = "application/x-www-form-urlencoded"
    public static let octetStream = "application/octet-stream"

    public static func multipart(boundary: String) -> String {
        "multipart/form-data; boundary=\(boundary)"
    }
}
