#if canImport(SwiftUI) && os(iOS)
import SwiftUI
import UIKit

public extension View {

    /// Dismisses the keyboard when the user taps anywhere on this view.
    ///
    /// Uses a *simultaneous* tap gesture, so buttons, list rows, and other
    /// controls keep working normally.
    ///
    /// ```swift
    /// Form { … }
    ///     .dismissKeyboardOnTap()
    /// ```
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                KeyboardDismisser.dismiss()
            }
        )
    }
}

/// Resigns the current first responder app-wide.
public enum KeyboardDismisser {
    @MainActor
    public static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
#endif
