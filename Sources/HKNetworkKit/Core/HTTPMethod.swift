import Foundation

/// The HTTP method used for a request.
public enum HTTPMethod: String, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    /// Whether this method conventionally carries a request body.
    public var allowsBody: Bool {
        switch self {
        case .post, .put, .patch, .delete:
            return true
        case .get, .head, .options:
            return false
        }
    }
}
