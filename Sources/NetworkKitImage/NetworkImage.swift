#if canImport(SwiftUI)
import SwiftUI

extension Image {
    /// Creates a SwiftUI `Image` from a platform image.
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

/// A SwiftUI view that asynchronously loads and displays a remote image using
/// SDWebImage's cache, showing a placeholder while loading.
///
/// ```swift
/// // Simplest form:
/// NetworkImage(url: user.avatarURL)
///     .frame(width: 80, height: 80)
///     .clipShape(Circle())
///
/// // With a custom placeholder:
/// NetworkImage(url: product.imageURL) {
///     ProgressView()
/// }
/// ```
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
public struct NetworkImage<Placeholder: View>: View {
    private let url: URL?
    private let placeholder: Placeholder

    @State private var image: PlatformImage?

    /// Creates a view with a custom placeholder shown while loading.
    public init(url: String?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url.flatMap(URL.init(string:))
        self.placeholder = placeholder()
    }

    public var body: some View {
        Group {
            if let image {
                Image(platformImage: image).resizable()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = try? await WebImageLoader.image(from: url)
        }
    }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
public extension NetworkImage where Placeholder == AnyView {
    /// Creates a view with the default placeholder (a centered progress spinner).
    init(url: String?) {
        self.init(url: url) {
            AnyView(
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
    }
}
#endif
