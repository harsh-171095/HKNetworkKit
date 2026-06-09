#if canImport(UIKit) && !os(watchOS)
import UIKit

private final class ImageLoadToken {
    let task: Task<Void, Never>
    init(_ task: Task<Void, Never>) { self.task = task }
}

private enum AssociatedKeys {
    nonisolated(unsafe) static var loadTask: UInt8 = 0
}

public extension UIImageView {

    /// Loads a remote image into the image view, with a placeholder and a
    /// built-in activity indicator while loading. Cache-aware and safe for
    /// reuse in cells (a new load cancels the previous one).
    ///
    /// ```swift
    /// avatarView.setImage(fromURL: user.avatarURL)
    /// ```
    ///
    /// - Parameters:
    ///   - url: The image URL string. An invalid string shows `placeholder`.
    ///   - placeholder: Image shown until the download finishes (or on failure).
    ///   - showsActivityIndicator: Show a spinner while loading. Default `true`.
    ///   - completion: Optional callback with the loaded image or an error.
    func setImage(
        fromURL url: String,
        placeholder: UIImage? = UIImage(named: "placeholder_icon"),
        showsActivityIndicator: Bool = true,
        completion: ((UIImage?, Error?) -> Void)? = nil
    ) {
        cancelImageLoad()

        // Synchronous memory-cache fast path — avoids a flash of the placeholder.
        if let cached = WebImageLoader.cachedImage(for: url) {
            self.image = cached
            completion?(cached, nil)
            return
        }

        self.image = placeholder

        guard URL(string: url) != nil else {
            completion?(nil, URLError(.badURL))
            return
        }

        let indicator = showsActivityIndicator ? startIndicator() : nil

        let task = Task { @MainActor in
            defer { indicator?.stopAndRemove() }
            do {
                let image = try await WebImageLoader.image(from: url)
                if Task.isCancelled { return }
                self.image = image
                completion?(image, nil)
            } catch {
                if Task.isCancelled { return }
                completion?(nil, error)
            }
        }
        objc_setAssociatedObject(self, &AssociatedKeys.loadTask, ImageLoadToken(task), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Alias for ``setImage(fromURL:placeholder:showsActivityIndicator:completion:)``.
    func loadImage(
        fromURL url: String,
        placeholder: UIImage? = UIImage(named: "placeholder_icon")
    ) {
        setImage(fromURL: url, placeholder: placeholder)
    }

    /// async/await variant. Returns the loaded image or throws.
    @discardableResult
    func setImage(
        fromURL url: String,
        placeholder: UIImage? = UIImage(named: "placeholder_icon")
    ) async throws -> UIImage {
        self.image = placeholder
        let image = try await WebImageLoader.image(from: url)
        self.image = image
        return image
    }

    /// Cancels any in-flight image load started by this view.
    func cancelImageLoad() {
        if let token = objc_getAssociatedObject(self, &AssociatedKeys.loadTask) as? ImageLoadToken {
            token.task.cancel()
        }
        objc_setAssociatedObject(self, &AssociatedKeys.loadTask, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func startIndicator() -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        indicator.startAnimating()
        return indicator
    }
}

private extension UIActivityIndicatorView {
    func stopAndRemove() {
        stopAnimating()
        removeFromSuperview()
    }
}

#if !os(tvOS)
public extension UIButton {
    /// Loads a remote image into the button for the given control state.
    func setImage(
        fromURL url: String,
        for state: UIControl.State = .normal,
        placeholder: UIImage? = UIImage(named: "placeholder_icon")
    ) {
        setImage(placeholder, for: state)
        Task { @MainActor in
            if let image = try? await WebImageLoader.image(from: url) {
                self.setImage(image, for: state)
            }
        }
    }
}
#endif
#endif
