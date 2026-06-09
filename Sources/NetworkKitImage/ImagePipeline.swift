import Foundation

/// Coordinates image loading: serves from cache, downloads on miss, and
/// de-duplicates concurrent requests for the same URL so each image is fetched
/// only once even when many views ask for it at the same time.
public actor ImagePipeline {

    public static let shared = ImagePipeline()

    private let cache: ImageCache
    private let session: URLSession
    private var inFlight: [String: Task<ImageBox, Error>] = [:]

    public init(cache: ImageCache = .shared, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    /// Loads the image for a URL, using the cache and coalescing duplicate loads.
    func image(for url: URL) async throws -> ImageBox {
        let key = url.absoluteString

        if let existing = inFlight[key] {
            return try await existing.value
        }

        let cache = self.cache
        let session = self.session
        let task = Task<ImageBox, Error> {
            if let cached = cache.image(forKey: key) {
                return ImageBox(image: cached)
            }
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            guard let image = PlatformImage.decode(from: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            cache.store(image, data: data, forKey: key)
            return ImageBox(image: image)
        }

        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }
}
