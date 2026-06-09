import Foundation
import CryptoKit

/// A two-tier image cache: a fast in-memory `NSCache` backed by a persistent
/// disk cache in the app's Caches directory.
public final class ImageCache: @unchecked Sendable {

    /// The shared cache used by ``WebImageLoader`` and the view helpers.
    public static let shared = ImageCache()

    private let memory = NSCache<NSString, PlatformImage>()
    private let fileManager = FileManager.default
    private let directory: URL

    /// - Parameters:
    ///   - memoryLimitBytes: Soft limit for the in-memory cache (default 100 MB).
    ///   - directoryName: Sub-folder name within the Caches directory.
    public init(memoryLimitBytes: Int = 100 * 1024 * 1024, directoryName: String = "HKNetworkKitImageCache") {
        memory.totalCostLimit = memoryLimitBytes
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = caches.appendingPathComponent(directoryName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Returns a decoded image from the in-memory cache only (synchronous, fast).
    public func memoryImage(forKey key: String) -> PlatformImage? {
        memory.object(forKey: key as NSString)
    }

    /// Returns an image from memory, falling back to disk (promoting on hit).
    public func image(forKey key: String) -> PlatformImage? {
        if let image = memoryImage(forKey: key) { return image }
        guard let data = try? Data(contentsOf: fileURL(forKey: key)),
              let image = PlatformImage.decode(from: data) else {
            return nil
        }
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        return image
    }

    /// Stores an image in both memory and disk caches.
    public func store(_ image: PlatformImage, data: Data, forKey key: String) {
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        try? data.write(to: fileURL(forKey: key), options: .atomic)
    }

    /// Removes everything from the in-memory cache.
    public func clearMemory() {
        memory.removeAllObjects()
    }

    /// Removes everything from the on-disk cache.
    public func clearDisk() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}
