import Foundation

/// The body payload of a request.
public enum RequestBody: Sendable {
    /// No body.
    case none
    /// Raw bytes sent verbatim.
    case data(Data)
    /// A `Codable` value encoded to JSON using the client's encoder.
    case json(any Encodable & Sendable)
    /// Key/value pairs encoded as `application/x-www-form-urlencoded`.
    case formURLEncoded([String: String])
    /// A multipart/form-data payload.
    case multipart(MultipartFormData)
}
