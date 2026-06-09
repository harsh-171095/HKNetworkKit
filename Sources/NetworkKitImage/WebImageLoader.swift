import Foundation

/// The public, easy-to-use facade for loading and caching remote images.
/// Backed by ``ImagePipeline`` and ``ImageCache`` — no third-party dependencies.
public enum WebImageLoader {

    /// Loads an image from a URL string.
    public static func image(from url: String) async throws -> PlatformImage {
        guard let imageURL = URL(string: url) else { throw URLError(.badURL) }
        return try await image(from: imageURL)
    }

    /// Loads an image from a `URL`.
    public static func image(from url: URL) async throws -> PlatformImage {
        try await ImagePipeline.shared.image(for: url).image
    }

    /// Returns a cached image immediately if present in memory (synchronous).
    public static func cachedImage(for url: String) -> PlatformImage? {
        ImageCache.shared.memoryImage(forKey: url)
    }

    /// Warms the cache for a set of URLs ahead of time. Fire-and-forget.
    public static func prefetch(_ urls: [String]) {
        for url in urls.compactMap(URL.init(string:)) {
            Task.detached(priority: .utility) {
                _ = try? await ImagePipeline.shared.image(for: url)
            }
        }
    }

    /// Clears the in-memory image cache.
    public static func clearMemoryCache() {
        ImageCache.shared.clearMemory()
    }

    /// Clears the on-disk image cache.
    public static func clearDiskCache() {
        ImageCache.shared.clearDisk()
    }
}
