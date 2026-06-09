import Foundation

/// A pairing of JSON encoder and decoder used by the client. Wrapped in a
/// `Sendable` box because `JSONEncoder`/`JSONDecoder` are not themselves Sendable.
public struct CoderConfiguration: @unchecked Sendable {
    public let encoder: JSONEncoder
    public let decoder: JSONDecoder

    public init(encoder: JSONEncoder, decoder: JSONDecoder) {
        self.encoder = encoder
        self.decoder = decoder
    }

    /// A sensible default: ISO-8601 dates, no special key strategy.
    public static var `default`: CoderConfiguration {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return CoderConfiguration(encoder: encoder, decoder: decoder)
    }

    /// snake_case keys converted to/from camelCase, ISO-8601 dates.
    public static var snakeCase: CoderConfiguration {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return CoderConfiguration(encoder: encoder, decoder: decoder)
    }
}
