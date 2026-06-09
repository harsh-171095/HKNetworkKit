import Foundation

/// Builds a `multipart/form-data` payload for file and image uploads.
public struct MultipartFormData: Sendable {
    /// A single part of the multipart body.
    public struct Part: Sendable {
        public let name: String
        public let fileName: String?
        public let mimeType: String?
        public let data: Data

        public init(name: String, fileName: String? = nil, mimeType: String? = nil, data: Data) {
            self.name = name
            self.fileName = fileName
            self.mimeType = mimeType
            self.data = data
        }
    }

    public let boundary: String
    private(set) var parts: [Part]

    public init(boundary: String = "NetworkKit-\(UUID().uuidString)") {
        self.boundary = boundary
        self.parts = []
    }

    /// Appends a plain text field.
    public mutating func append(_ value: String, name: String) {
        parts.append(Part(name: name, data: Data(value.utf8)))
    }

    /// Appends a file or binary field.
    public mutating func append(
        _ data: Data,
        name: String,
        fileName: String,
        mimeType: String
    ) {
        parts.append(Part(name: name, fileName: fileName, mimeType: mimeType, data: data))
    }

    /// The encoded HTTP body for these parts.
    public func encode() -> Data {
        var body = Data()
        let crlf = "\r\n"

        for part in parts {
            body.append(Data("--\(boundary)\(crlf)".utf8))

            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let fileName = part.fileName {
                disposition += "; filename=\"\(fileName)\""
            }
            body.append(Data("\(disposition)\(crlf)".utf8))

            if let mimeType = part.mimeType {
                body.append(Data("Content-Type: \(mimeType)\(crlf)".utf8))
            }

            body.append(Data(crlf.utf8))
            body.append(part.data)
            body.append(Data(crlf.utf8))
        }

        body.append(Data("--\(boundary)--\(crlf)".utf8))
        return body
    }
}
