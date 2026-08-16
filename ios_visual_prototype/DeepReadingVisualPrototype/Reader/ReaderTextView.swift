import SwiftUI
import UIKit

struct ReaderScrollEventClassifier {
    private var previousOffset: CGFloat = 0

    mutating func direction(for offset: CGFloat, isUserDriven: Bool) -> ReaderCoordinator.ScrollDirection? {
        defer { previousOffset = offset }
        guard isUserDriven else { return nil }
        if offset > previousOffset { return .down }
        if offset < previousOffset { return .up }
        return nil
    }
}

struct ReaderTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let requestedScrollRange: NSRange?
    let onVisibleUTF16Location: (Int) -> Void
    let onScrollDirection: (ReaderCoordinator.ScrollDirection) -> Void
    let onBodyTap: () -> Void

    func makeCoordinator() -> TextViewCoordinator {
        TextViewCoordinator(
            onVisibleUTF16Location: onVisibleUTF16Location,
            onScrollDirection: onScrollDirection,
            onBodyTap: onBodyTap
        )
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = UIEdgeInsets(top: 116, left: 28, bottom: 122, right: 28)
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.accessibilityIdentifier = "reader-text-view"
        textView.addGestureRecognizer(context.coordinator.bodyTapRecognizer)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.updateCallbacks(
            onVisibleUTF16Location: onVisibleUTF16Location,
            onScrollDirection: onScrollDirection,
            onBodyTap: onBodyTap
        )
        if !textView.attributedText.isEqual(to: attributedText) {
            let selectedRange = textView.selectedRange
            textView.attributedText = attributedText
            if selectedRange.location <= textView.attributedText.length {
                textView.selectedRange = selectedRange
            }
        }
        guard let requestedScrollRange,
              requestedScrollRange.location <= textView.attributedText.length,
              !NSEqualRanges(context.coordinator.lastScrollRange, requestedScrollRange) else { return }
        context.coordinator.lastScrollRange = requestedScrollRange
        DispatchQueue.main.async {
            context.coordinator.isRestoringRange = true
            textView.scrollRangeToVisible(requestedScrollRange)
            context.coordinator.isRestoringRange = false
        }
    }

    final class TextViewCoordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var lastScrollRange = NSRange(location: NSNotFound, length: 0)
        private var scrollClassifier = ReaderScrollEventClassifier()
        fileprivate var isRestoringRange = false
        private var onVisibleUTF16Location: (Int) -> Void
        private var onScrollDirection: (ReaderCoordinator.ScrollDirection) -> Void
        private var onBodyTap: () -> Void
        lazy var bodyTapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleBodyTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        init(
            onVisibleUTF16Location: @escaping (Int) -> Void,
            onScrollDirection: @escaping (ReaderCoordinator.ScrollDirection) -> Void,
            onBodyTap: @escaping () -> Void
        ) {
            self.onVisibleUTF16Location = onVisibleUTF16Location
            self.onScrollDirection = onScrollDirection
            self.onBodyTap = onBodyTap
        }

        func updateCallbacks(
            onVisibleUTF16Location: @escaping (Int) -> Void,
            onScrollDirection: @escaping (ReaderCoordinator.ScrollDirection) -> Void,
            onBodyTap: @escaping () -> Void
        ) {
            self.onVisibleUTF16Location = onVisibleUTF16Location
            self.onScrollDirection = onScrollDirection
            self.onBodyTap = onBodyTap
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset.y
            let isUserDriven = !isRestoringRange && (scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating)
            if let direction = scrollClassifier.direction(for: offset, isUserDriven: isUserDriven) {
                onScrollDirection(direction)
            }

            guard let textView = scrollView as? UITextView else { return }
            let point = CGPoint(
                x: 1,
                y: max(0, textView.contentOffset.y + textView.textContainerInset.top)
            )
            let location = textView.layoutManager.characterIndex(
                for: point,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            onVisibleUTF16Location(location)
        }

        @objc private func handleBodyTap() {
            guard bodyTapRecognizer.state == .ended,
                  let textView = bodyTapRecognizer.view as? UITextView,
                  textView.selectedRange.length == 0 else { return }
            onBodyTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool { true }
    }
}
