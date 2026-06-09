import Foundation

#if canImport(UIKit)
import UIKit
/// The platform image type (`UIImage` on iOS/tvOS/watchOS).
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// The platform image type (`NSImage` on macOS).
public typealias PlatformImage = NSImage
#endif

extension PlatformImage {
    /// Decodes a platform image from raw data.
    static func decode(from data: Data) -> PlatformImage? {
        PlatformImage(data: data)
    }
}

/// A `Sendable` wrapper allowing a decoded (and effectively immutable) image to
/// cross concurrency boundaries. Images are not mutated after decoding, so this
/// is safe in practice.
struct ImageBox: @unchecked Sendable {
    let image: PlatformImage
}
