import Foundation

extension Encodable {
    /// Encodes the value to JSON, wrapping any failure in `APIError.encoding`.
    func encoded(using encoder: JSONEncoder) throws -> Data {
        do {
            return try encoder.encode(self)
        } catch {
            throw APIError.encoding(underlying: error)
        }
    }
}

extension Data {
    /// Decodes the data into `T`, wrapping any failure in `APIError.decoding`.
    func decoded<T: Decodable>(as type: T.Type, using decoder: JSONDecoder) throws -> T {
        do {
            return try decoder.decode(T.self, from: self)
        } catch {
            throw APIError.decoding(underlying: error)
        }
    }
}
