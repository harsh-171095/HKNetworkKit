import Foundation

/// A decoded response paired with its metadata.
public struct NetworkResponse<Value: Sendable>: Sendable {
    /// The decoded value.
    public let value: Value
    /// The raw response body.
    public let data: Data
    /// The underlying HTTP URL response.
    public let httpResponse: HTTPURLResponse

    public init(value: Value, data: Data, httpResponse: HTTPURLResponse) {
        self.value = value
        self.data = data
        self.httpResponse = httpResponse
    }

    /// The HTTP status code.
    public var statusCode: Int { httpResponse.statusCode }

    /// The response headers.
    public var headers: HTTPHeaders {
        var headers = HTTPHeaders()
        for (key, value) in httpResponse.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers.set(value, for: key)
            }
        }
        return headers
    }
}
