#if os(iOS)
import UIKit

extension KeyboardManager {

    /// Installs a Previous/Next/Done accessory toolbar on the given input,
    /// enabling navigation based on the field's position among its siblings.
    func applyToolbar(to input: UIView) {
        let inputs = navigableInputs(for: input)
        let index = inputs.firstIndex(of: input) ?? 0
        let toolbar = makeToolbar(
            hasPrevious: index > 0,
            hasNext: index < inputs.count - 1
        )

        if let textField = input as? UITextField {
            textField.inputAccessoryView = toolbar
            textField.reloadInputViews()
        } else if let textView = input as? UITextView {
            textView.inputAccessoryView = toolbar
            textView.reloadInputViews()
        }
    }

    private func makeToolbar(hasPrevious: Bool, hasNext: Bool) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        if let tint = toolbarTintColor { toolbar.tintColor = tint }

        let previous = UIBarButtonItem(title: toolbarPreviousTitle, style: .plain,
                                       target: self, action: #selector(toolbarPrevious))
        previous.isEnabled = hasPrevious

        let next = UIBarButtonItem(title: toolbarNextTitle, style: .plain,
                                   target: self, action: #selector(toolbarNext))
        next.isEnabled = hasNext

        let gap = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        gap.width = 16

        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let done = UIBarButtonItem(title: toolbarDoneTitle, style: .done,
                                   target: self, action: #selector(toolbarDone))

        toolbar.items = [previous, gap, next, flexible, done]
        return toolbar
    }

    @objc private func toolbarPrevious() { moveResponder(by: -1) }
    @objc private func toolbarNext() { moveResponder(by: 1) }
    @objc private func toolbarDone() { currentInput?.window?.endEditing(true) }

    private func moveResponder(by offset: Int) {
        guard let current = currentInput else { return }
        let inputs = navigableInputs(for: current)
        guard let index = inputs.firstIndex(of: current) else { return }
        let target = index + offset
        guard inputs.indices.contains(target) else { return }
        inputs[target].becomeFirstResponder()
    }

    /// All text inputs in the field's screen, sorted top-to-bottom, left-to-right.
    private func navigableInputs(for input: UIView) -> [UIView] {
        let container = input.owningViewController?.view ?? input.window ?? input
        return container.descendantTextInputs().sorted { lhs, rhs in
            let lhsFrame = lhs.convert(lhs.bounds, to: container)
            let rhsFrame = rhs.convert(rhs.bounds, to: container)
            if abs(lhsFrame.minY - rhsFrame.minY) > 1 { return lhsFrame.minY < rhsFrame.minY }
            return lhsFrame.minX < rhsFrame.minX
        }
    }
}
#endif
