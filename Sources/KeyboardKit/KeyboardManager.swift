#if os(iOS)
import UIKit

/// Automatic, app-wide keyboard handling for UIKit — a custom, dependency-free
/// alternative to IQKeyboardManagerSwift.
///
/// Enable it once (e.g. in `application(_:didFinishLaunchingWithOptions:)`):
///
/// ```swift
/// KeyboardManager.shared.isEnabled = true
/// ```
///
/// From then on, every `UITextField`/`UITextView` in the app is automatically
/// kept visible above the keyboard, gets a Previous/Next/Done toolbar, and the
/// keyboard dismisses on a tap outside. No per-screen code required.
@MainActor
public final class KeyboardManager: NSObject {

    /// The shared, app-wide manager.
    public static let shared = KeyboardManager()

    // MARK: Configuration

    /// Turns automatic handling on/off. Setting `false` restores any moved view.
    public var isEnabled: Bool = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }
    /// Gap kept between the bottom of the field and the top of the keyboard.
    public var keyboardDistanceFromTextField: CGFloat = 10
    /// Dismiss the keyboard when the user taps outside the active field.
    public var resignOnTouchOutside: Bool = true
    /// Add a Previous/Next/Done accessory toolbar to each field.
    public var isToolbarEnabled: Bool = true
    /// Optional tint color for the toolbar buttons.
    public var toolbarTintColor: UIColor?
    /// Toolbar button titles.
    public var toolbarDoneTitle = "Done"
    public var toolbarPreviousTitle = "Previous"
    public var toolbarNextTitle = "Next"

    /// View controller classes for which handling is completely skipped.
    private var disabledClassIDs = Set<ObjectIdentifier>()

    /// Disables all keyboard handling for fields owned by this view controller type.
    public func disable(for viewControllerType: UIViewController.Type) {
        disabledClassIDs.insert(ObjectIdentifier(viewControllerType))
    }

    /// Re-enables handling for a previously disabled view controller type.
    public func enable(for viewControllerType: UIViewController.Type) {
        disabledClassIDs.remove(ObjectIdentifier(viewControllerType))
    }

    /// Whether handling is disabled for the view controller owning `input`.
    private func isDisabled(for input: UIView) -> Bool {
        guard let viewController = input.owningViewController else { return false }
        return disabledClassIDs.contains(ObjectIdentifier(type(of: viewController)))
    }

    // MARK: State

    private weak var activeInput: UIView?
    private weak var adjustedScrollView: UIScrollView?
    private var originalScrollInset: UIEdgeInsets?
    private weak var movedView: UIView?
    private var originalViewOriginY: CGFloat?
    private var keyboardFrame: CGRect = .zero
    private var tapGesture: UITapGestureRecognizer?

    private override init() { super.init() }

    // MARK: Lifecycle

    private func start() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(didBeginEditing(_:)),
                           name: UITextField.textDidBeginEditingNotification, object: nil)
        center.addObserver(self, selector: #selector(didBeginEditing(_:)),
                           name: UITextView.textDidBeginEditingNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardChanged(_:)),
                           name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardChanged(_:)),
                           name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                           name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func stop() {
        NotificationCenter.default.removeObserver(self)
        removeTapGesture()
        restore(duration: 0, curve: 7)
        activeInput = nil
        keyboardFrame = .zero
    }

    // MARK: Notifications

    @objc private func didBeginEditing(_ note: Notification) {
        guard isEnabled, let input = note.object as? UIView, !isDisabled(for: input) else { return }
        activeInput = input
        if isToolbarEnabled { applyToolbar(to: input) }
        addTapGesture(to: input.window)
        if keyboardFrame != .zero { adjust(for: input) }
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard isEnabled,
              let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        keyboardFrame = end
        let (duration, curve) = animationInfo(note)
        if let input = activeInput ?? activeResponder() {
            guard !isDisabled(for: input) else { return }
            activeInput = input
            adjust(for: input, duration: duration, curve: curve)
        }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        guard isEnabled else { return }
        keyboardFrame = .zero
        let (duration, curve) = animationInfo(note)
        restore(duration: duration, curve: curve)
        removeTapGesture()
        activeInput = nil
    }

    // MARK: Avoidance

    private func adjust(for input: UIView, duration: TimeInterval = 0.25, curve: UInt = 7) {
        guard let window = input.window, keyboardFrame != .zero else { return }
        let keyboard = window.convert(keyboardFrame, from: window.screen.coordinateSpace)

        if let scrollView = input.enclosingScrollView {
            if adjustedScrollView !== scrollView {
                originalScrollInset = scrollView.contentInset
                adjustedScrollView = scrollView
            }
            let scrollFrame = scrollView.convert(scrollView.bounds, to: window)
            let overlap = max(0, scrollFrame.maxY - keyboard.minY)
            var inset = originalScrollInset ?? scrollView.contentInset
            inset.bottom = overlap + keyboardDistanceFromTextField
            let fieldRect = input.convert(input.bounds, to: scrollView)
                .insetBy(dx: 0, dy: -keyboardDistanceFromTextField)
            animate(duration, curve) {
                scrollView.contentInset = inset
                scrollView.verticalScrollIndicatorInsets = inset
                scrollView.scrollRectToVisible(fieldRect, animated: false)
            }
        } else {
            let root = input.owningViewController?.view ?? window
            if movedView !== root {
                movedView = root
                originalViewOriginY = root.frame.origin.y
            }
            let fieldFrame = input.convert(input.bounds, to: window)
            let overlap = max(0, fieldFrame.maxY + keyboardDistanceFromTextField - keyboard.minY)
            let baseY = originalViewOriginY ?? root.frame.origin.y
            animate(duration, curve) { root.frame.origin.y = baseY - overlap }
        }
    }

    private func restore(duration: TimeInterval, curve: UInt) {
        let scrollView = adjustedScrollView
        let inset = originalScrollInset
        let view = movedView
        let originY = originalViewOriginY
        animate(duration, curve) {
            if let scrollView, let inset {
                scrollView.contentInset = inset
                scrollView.verticalScrollIndicatorInsets = inset
            }
            if let view, let originY { view.frame.origin.y = originY }
        }
        adjustedScrollView = nil
        originalScrollInset = nil
        movedView = nil
        originalViewOriginY = nil
    }

    // MARK: Tap to dismiss

    private func addTapGesture(to window: UIWindow?) {
        guard resignOnTouchOutside, let window, tapGesture == nil else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        tapGesture = tap
    }

    private func removeTapGesture() {
        tapGesture?.view?.removeGestureRecognizer(tapGesture!)
        tapGesture = nil
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        gesture.view?.endEditing(true)
    }

    // MARK: Helpers

    private func activeResponder() -> UIView? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for window in windows where window.isKeyWindow {
            if let responder = window.activeFirstResponder() { return responder }
        }
        return nil
    }

    private func animationInfo(_ note: Notification) -> (TimeInterval, UInt) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        let curve = (note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
        return (duration, curve)
    }

    private func animate(_ duration: TimeInterval, _ curve: UInt, _ body: @escaping () -> Void) {
        guard duration > 0 else { body(); return }
        let options = UIView.AnimationOptions(rawValue: curve << 16).union(.beginFromCurrentState)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: body)
    }

    /// Exposes the current active input for the toolbar extension.
    var currentInput: UIView? { activeInput }
}

// MARK: - Tap gesture delegate

extension KeyboardManager: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive touch: UITouch) -> Bool {
        // Let buttons and other controls handle their own taps.
        !(touch.view is UIControl)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
#endif
