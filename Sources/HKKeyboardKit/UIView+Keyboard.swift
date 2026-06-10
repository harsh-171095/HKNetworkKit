#if os(iOS)
import UIKit

extension UIView {

    /// The view controller that owns this view, if any.
    var owningViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController { return viewController }
            responder = current.next
        }
        return nil
    }

    /// The nearest ancestor scroll view, if this view lives inside one.
    var enclosingScrollView: UIScrollView? {
        var view = superview
        while let current = view {
            if let scrollView = current as? UIScrollView { return scrollView }
            view = current.superview
        }
        return nil
    }

    /// The first responder within this view's hierarchy, if any.
    func activeFirstResponder() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let responder = subview.activeFirstResponder() { return responder }
        }
        return nil
    }

    /// All visible, interactive `UITextField`/`UITextView`s in this hierarchy.
    func descendantTextInputs() -> [UIView] {
        var result: [UIView] = []
        for subview in subviews {
            if subview is UITextField || subview is UITextView,
               subview.isUserInteractionEnabled, !subview.isHidden {
                result.append(subview)
            }
            result.append(contentsOf: subview.descendantTextInputs())
        }
        return result
    }
}
#endif
