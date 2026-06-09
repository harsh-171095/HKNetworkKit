import Foundation

/// Validates an HTTP response, mapping unacceptable status codes to `APIError`.
public protocol ResponseValidator: Sendable {
    func validate(data: Data, response: HTTPURLResponse) throws
}

/// The default validator: treats 200–299 as success and classifies common
/// failure codes into their dedicated `APIError` cases.
public struct DefaultResponseValidator: ResponseValidator {
    public let acceptableStatusCodes: Range<Int>

    public init(acceptableStatusCodes: Range<Int> = 200..<300) {
        self.acceptableStatusCodes = acceptableStatusCodes
    }

    public func validate(data: Data, response: HTTPURLResponse) throws {
        let code = response.statusCode
        guard !acceptableStatusCodes.contains(code) else { return }

        switch code {
        case 401:
            throw APIError.unauthorized(data: data)
        case 403:
            throw APIError.forbidden(data: data)
        case 404:
            throw APIError.notFound(data: data)
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw APIError.rateLimited(retryAfter: retryAfter, data: data)
        case 500...599:
            throw APIError.server(statusCode: code, data: data)
        default:
            throw APIError.unacceptableStatusCode(statusCode: code, data: data)
        }
    }
}
