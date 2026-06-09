import Foundation

/// Translates an ``Endpoint`` plus the client configuration into a `URLRequest`.
struct URLRequestBuilder {
    let configuration: NetworkConfiguration

    func makeRequest(for endpoint: any Endpoint) throws -> URLRequest {
        let base = endpoint.baseURL ?? configuration.baseURL
        let trimmedPath = endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path

        guard var components = URLComponents(
            url: base.appendingPathComponent(trimmedPath),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL(base.absoluteString + "/" + trimmedPath)
        }

        if !endpoint.queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + endpoint.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL(components.description)
        }

        if configuration.enforcesHTTPS, url.scheme?.lowercased() != "https" {
            throw APIError.ssl(reason: "HTTPS is required but URL scheme was \(url.scheme ?? "nil").")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout ?? configuration.timeout
        request.cachePolicy = endpoint.cachePolicy.urlRequestPolicy

        // Headers: defaults < endpoint-specific.
        var headers = configuration.defaultHeaders
        headers.merge(endpoint.headers)
        if let accept = endpoint.accept {
            headers.set(accept, for: HeaderField.accept)
        }

        try applyBody(endpoint.body, to: &request, headers: &headers, contentTypeOverride: endpoint.contentType)

        request.allHTTPHeaderFields = headers.dictionary
        return request
    }

    private func applyBody(
        _ body: RequestBody,
        to request: inout URLRequest,
        headers: inout HTTPHeaders,
        contentTypeOverride: String?
    ) throws {
        switch body {
        case .none:
            break

        case .data(let data):
            request.httpBody = data
            if let contentTypeOverride {
                headers.set(contentTypeOverride, for: HeaderField.contentType)
            }

        case .json(let value):
            request.httpBody = try value.encoded(using: configuration.coders.encoder)
            headers.set(contentTypeOverride ?? ContentType.json, for: HeaderField.contentType)

        case .formURLEncoded(let pairs):
            var components = URLComponents()
            components.queryItems = pairs.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = components.percentEncodedQuery.map { Data($0.utf8) }
            headers.set(contentTypeOverride ?? ContentType.formURLEncoded, for: HeaderField.contentType)

        case .multipart(let form):
            request.httpBody = form.encode()
            headers.set(ContentType.multipart(boundary: form.boundary), for: HeaderField.contentType)
        }
    }
}
