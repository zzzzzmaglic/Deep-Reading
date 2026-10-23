import SwiftUI
import UIKit

/// Draws persisted highlights as Figma-style underlines. They use real glyph
/// fragments, rather than a paragraph-wide UIKit background, so a multi-line
/// anchor gets one line per visual row and never colours paragraph leading.
private final class ReaderHighlightLayoutManager: NSLayoutManager {
    private let underlineThickness: CGFloat = 3
    private let underlineGapBelowLineBox: CGFloat = 1

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        let visibleCharacters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        textStorage?.enumerateAttribute(
            .readerHighlightTint,
            in: visibleCharacters,
            options: []
        ) { [weak self] value, characterRange, _ in
            guard let self,
                  let tint = value as? UIColor,
                  let textContainer = self.textContainers.first else { return }

            let glyphRange = self.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
            self.enumerateLineFragments(forGlyphRange: glyphRange) {
                [weak self] lineRect, _, container, lineGlyphRange, _ in
                guard let self,
                      let context = UIGraphicsGetCurrentContext() else { return }
                let highlightedGlyphs = NSIntersectionRange(glyphRange, lineGlyphRange)
                guard highlightedGlyphs.length > 0 else { return }

                let glyphBounds = self.boundingRect(
                    forGlyphRange: highlightedGlyphs,
                    in: container
                )
                guard glyphBounds.width > 0 else { return }
                let underlineRect = CGRect(
                    x: glyphBounds.minX + origin.x,
                    // This deliberately sits just below—not inside—the
                    // 28pt line box. The earlier `min(lineRect.maxY - …)`
                    // clamp prevented all attempted downward adjustment.
                    y: lineRect.maxY + origin.y + self.underlineGapBelowLineBox,
                    width: glyphBounds.width,
                    height: self.underlineThickness
                ).integral
                context.setFillColor(tint.cgColor)
                context.fill(underlineRect)
            }
        }
    }

}

struct ReaderScrollEventClassifier {
    private var previousOffset: CGFloat = 0

    static func isUserDriven(
        isTracking: Bool,
        isDragging: Bool,
        isDecelerating: Bool,
        isRestoringRange: Bool
    ) -> Bool {
        !isRestoringRange && (isTracking || isDragging || isDecelerating)
    }

    mutating func direction(for offset: CGFloat, isUserDriven: Bool) -> ReaderCoordinator.ScrollDirection? {
        defer { previousOffset = offset }
        guard isUserDriven else { return nil }
        if offset > previousOffset { return .down }
        if offset < previousOffset { return .up }
        return nil
    }
}

struct ReaderTextDocumentRevision: Equatable {
    let articleID: UUID
    let contentChecksum: String
    let highlights: [TextAnchor]
}

/// A reader route can request the same UTF-16 range as an earlier restored
/// progress position. Keep the route in the identity so returning from the
/// summary always remains a fresh navigation command.
struct ReaderScrollRequest: Equatable {
    let route: ReaderRoute
    let range: NSRange
}

struct ReaderTextDocumentUpdateGate {
    private var appliedRevision: ReaderTextDocumentRevision?

    mutating func shouldApply(_ revision: ReaderTextDocumentRevision) -> Bool {
        guard appliedRevision != revision else { return false }
        appliedRevision = revision
        return true
    }
}

struct ReaderTextView: UIViewRepresentable {
    let layout: ReaderTextLayout
    let highlights: [TextAnchor]
    let documentRevision: ReaderTextDocumentRevision
    let requestedScrollRequest: ReaderScrollRequest?
    let onVisibleUTF16Location: (Int) -> Void
    let onScrollDirection: (ReaderCoordinator.ScrollDirection) -> Void
    let onBodyTap: () -> Void
    let onInitialScrollApplied: () -> Void
    let selectedText: (NSRange) -> String?
    let normalizedSelection: (NSRange) -> NSRange?
    let isStandaloneLayoutSelection: (NSRange) -> Bool
    let highlightedAnchorAt: (Int) -> TextAnchor?
    let highlightedAnchorIntersecting: (NSRange) -> TextAnchor?
    let highlightedAnchorRange: (TextAnchor) -> NSRange?
    let onSelectionAction: (NSRange, ReaderSelectionAction) -> Void
    let onHighlightedTextAction: (TextAnchor, ReaderSelectionAction) -> Void
    let onCompleteReading: () -> Void
    /// Keep UIKit's native bottom scroll-edge treatment in step with the
    /// reader controls that sit over the same edge.
    let showsBottomEdgeEffect: Bool

    func makeCoordinator() -> TextViewCoordinator {
        TextViewCoordinator(
            onVisibleUTF16Location: onVisibleUTF16Location,
            onScrollDirection: onScrollDirection,
            onBodyTap: onBodyTap,
            onInitialScrollApplied: onInitialScrollApplied,
            selectedText: selectedText,
            normalizedSelection: normalizedSelection,
            isStandaloneLayoutSelection: isStandaloneLayoutSelection,
            highlightedAnchorAt: highlightedAnchorAt,
            highlightedAnchorIntersecting: highlightedAnchorIntersecting,
            highlightedAnchorRange: highlightedAnchorRange,
            onSelectionAction: onSelectionAction,
            onHighlightedTextAction: onHighlightedTextAction
        )
    }

    func makeUIView(context: Context) -> ReaderViewportTextView {
        // Progress anchoring uses the legacy NSLayoutManager API below. Choose
        // TextKit 1 at creation time so UIKit never switches engines during an
        // active pan and resets the reader's contentOffset to the top.
        let textStorage = NSTextStorage()
        let layoutManager = ReaderHighlightLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let textView = ReaderViewportTextView(frame: .zero, textContainer: textContainer)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.contentInsetAdjustmentBehavior = .never
        textView.bottomEdgeEffect.style = .soft
        textView.bottomEdgeEffect.isHidden = !showsBottomEdgeEffect
        // The chrome is a non-layout overlay. Reserve its visual space here
        // instead of using SwiftUI safeAreaBar, which changes UIKit scroll-view
        // geometry whenever the chrome transitions.
        // The 148pt progressive top edge ends above the title. Start the text
        // at 164pt so the visible title never sits under chrome or its mask.
        textView.textContainerInset = UIEdgeInsets(
            top: 164,
            left: 28,
            bottom: ReaderCompletionControlLayout.textContainerBottomInset,
            right: 28
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.accessibilityIdentifier = "reader-text-view"
        textView.onCompleteReading = onCompleteReading
        textView.addGestureRecognizer(context.coordinator.bodyTapRecognizer)
        // A drag belongs exclusively to UITextView's built-in pan recognizer.
        // A tap is recognized only after that pan has failed, so chrome toggles
        // cannot compete with a reading gesture.
        context.coordinator.bodyTapRecognizer.require(toFail: textView.panGestureRecognizer)
        context.coordinator.bodyTapRecognizer.delegate = context.coordinator
        let highlightedTextMenu = UIEditMenuInteraction(delegate: context.coordinator)
        textView.addInteraction(highlightedTextMenu)
        context.coordinator.highlightedTextMenu = highlightedTextMenu
        textView.onViewportLayout = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else { return }
            coordinator.applyPendingScrollIfReady(in: textView)
        }
        return textView
    }

    /// A UITextView reports a content-driven fitting size by default. Returning
    /// the proposed size makes it a fixed reader viewport instead of a very
    /// tall static view that extends past the screen and cannot be scrolled.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ReaderViewportTextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }

    func updateUIView(_ textView: ReaderViewportTextView, context: Context) {
        textView.bottomEdgeEffect.style = .soft
        textView.bottomEdgeEffect.isHidden = !showsBottomEdgeEffect
        textView.onCompleteReading = onCompleteReading
        context.coordinator.updateCallbacks(
            onVisibleUTF16Location: onVisibleUTF16Location,
            onScrollDirection: onScrollDirection,
            onBodyTap: onBodyTap,
            onInitialScrollApplied: onInitialScrollApplied,
            selectedText: selectedText,
            normalizedSelection: normalizedSelection,
            isStandaloneLayoutSelection: isStandaloneLayoutSelection,
            highlightedAnchorAt: highlightedAnchorAt,
            highlightedAnchorIntersecting: highlightedAnchorIntersecting,
            highlightedAnchorRange: highlightedAnchorRange,
            onSelectionAction: onSelectionAction,
            onHighlightedTextAction: onHighlightedTextAction
        )
        let documentChanged = context.coordinator.documentUpdateGate.shouldApply(documentRevision)
        let offsetBeforeDocumentChange = textView.contentOffset
        if documentChanged {
            let selectedRange = textView.selectedRange
            textView.attributedText = layout.attributedText(highlighting: highlights)
            if selectedRange.location <= textView.attributedText.length {
                textView.selectedRange = selectedRange
            }
        }
        if let requestedScrollRequest,
           requestedScrollRequest.range.location <= textView.attributedText.length {
            context.coordinator.requestScroll(requestedScrollRequest, in: textView)
            return
        }

        // Replacing attributedText can reset UIKit's offset. Preserve only
        // this real document mutation; ordinary SwiftUI updates must never
        // write contentOffset, or an upward drag can be forced back to 0.
        guard documentChanged, textView.window != nil else { return }
        let documentRestoreToken = context.coordinator.beginDocumentOffsetRestore()
        DispatchQueue.main.async {
            guard context.coordinator.isCurrentDocumentOffsetRestore(documentRestoreToken) else {
                return
            }
            context.coordinator.isRestoringRange = true
            let maximumOffset = max(
                -textView.adjustedContentInset.top,
                textView.contentSize.height - textView.bounds.height + textView.adjustedContentInset.bottom
            )
            textView.setContentOffset(
                CGPoint(x: textView.contentOffset.x, y: min(max(offsetBeforeDocumentChange.y, -textView.adjustedContentInset.top), maximumOffset)),
                animated: false
            )
            context.coordinator.isRestoringRange = false
        }
    }

    final class ReaderViewportTextView: UITextView {
        var onViewportLayout: (() -> Void)?
        var onCompleteReading: (() -> Void)?
        let completionButton = UIButton(type: .custom)
        private weak var scrollEdgeOwner: UIViewController?

        override init(frame: CGRect, textContainer: NSTextContainer?) {
            super.init(frame: frame, textContainer: textContainer)
            configureCompletionButton()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            configureCompletionButton()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if window == nil {
                if scrollEdgeOwner?.contentScrollView(for: .top) === self {
                    scrollEdgeOwner?.setContentScrollView(nil, for: .top)
                }
                scrollEdgeOwner = nil
                return
            }

            guard let owner = owningViewController else { return }
            owner.setContentScrollView(self, for: .top)
            scrollEdgeOwner = owner
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layoutManager.ensureLayout(for: textContainer)
            let usedTextRect = layoutManager.usedRect(for: textContainer)
            completionButton.frame = CGRect(
                x: (bounds.width - ReaderCompletionControlLayout.size) / 2,
                y: textContainerInset.top + usedTextRect.maxY + ReaderCompletionControlLayout.topSpacing,
                width: ReaderCompletionControlLayout.size,
                height: ReaderCompletionControlLayout.size
            )
            completionButton.layer.cornerRadius = ReaderCompletionControlLayout.size / 2
            onViewportLayout?()
        }

        private func configureCompletionButton() {
            completionButton.backgroundColor = UIColor(white: 0.592, alpha: 0.10)
            completionButton.layer.borderColor = UIColor(white: 0.731, alpha: 1).cgColor
            completionButton.layer.borderWidth = 3
            completionButton.setTitle("✓", for: .normal)
            completionButton.setTitleColor(UIColor(white: 0.731, alpha: 1), for: .normal)
            completionButton.titleLabel?.font = .systemFont(ofSize: 36, weight: .medium)
            completionButton.accessibilityLabel = "完成阅读"
            completionButton.accessibilityIdentifier = "reader-complete-reading"
            completionButton.addTarget(self, action: #selector(completeReading), for: .touchUpInside)
            addSubview(completionButton)
        }

        @objc private func completeReading() {
            onCompleteReading?()
        }

        private var owningViewController: UIViewController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController { return controller }
                responder = current.next
            }
            return nil
        }
    }

    final class TextViewCoordinator: NSObject, UITextViewDelegate, UIEditMenuInteractionDelegate, UIGestureRecognizerDelegate {
        private var lastScrollRequest: ReaderScrollRequest?
        private var pendingScrollRequest: ReaderScrollRequest?
        private var documentOffsetRestoreToken = 0
        var documentUpdateGate = ReaderTextDocumentUpdateGate()
        private var scrollClassifier = ReaderScrollEventClassifier()
        private var isUserScrollSession = false
        fileprivate var isRestoringRange = false
        private var onVisibleUTF16Location: (Int) -> Void
        private var onScrollDirection: (ReaderCoordinator.ScrollDirection) -> Void
        private var onBodyTap: () -> Void
        fileprivate var onInitialScrollApplied: () -> Void
        private var selectedText: (NSRange) -> String?
        private var normalizedSelection: (NSRange) -> NSRange?
        private var isStandaloneLayoutSelection: (NSRange) -> Bool
        private var highlightedAnchorAt: (Int) -> TextAnchor?
        private var highlightedAnchorIntersecting: (NSRange) -> TextAnchor?
        private var highlightedAnchorRange: (TextAnchor) -> NSRange?
        private var onSelectionAction: (NSRange, ReaderSelectionAction) -> Void
        private var onHighlightedTextAction: (TextAnchor, ReaderSelectionAction) -> Void
        private var activeHighlightedAnchor: TextAnchor?
        private var suppressHighlightedSelectionClear = false
        weak var highlightedTextMenu: UIEditMenuInteraction?
        lazy var bodyTapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleBodyTap))
            recognizer.cancelsTouchesInView = false
            return recognizer
        }()

        init(
            onVisibleUTF16Location: @escaping (Int) -> Void,
            onScrollDirection: @escaping (ReaderCoordinator.ScrollDirection) -> Void,
            onBodyTap: @escaping () -> Void,
            onInitialScrollApplied: @escaping () -> Void,
            selectedText: @escaping (NSRange) -> String?,
            normalizedSelection: @escaping (NSRange) -> NSRange?,
            isStandaloneLayoutSelection: @escaping (NSRange) -> Bool,
            highlightedAnchorAt: @escaping (Int) -> TextAnchor?,
            highlightedAnchorIntersecting: @escaping (NSRange) -> TextAnchor?,
            highlightedAnchorRange: @escaping (TextAnchor) -> NSRange?,
            onSelectionAction: @escaping (NSRange, ReaderSelectionAction) -> Void,
            onHighlightedTextAction: @escaping (TextAnchor, ReaderSelectionAction) -> Void
        ) {
            self.onVisibleUTF16Location = onVisibleUTF16Location
            self.onScrollDirection = onScrollDirection
            self.onBodyTap = onBodyTap
            self.onInitialScrollApplied = onInitialScrollApplied
            self.selectedText = selectedText
            self.normalizedSelection = normalizedSelection
            self.isStandaloneLayoutSelection = isStandaloneLayoutSelection
            self.highlightedAnchorAt = highlightedAnchorAt
            self.highlightedAnchorIntersecting = highlightedAnchorIntersecting
            self.highlightedAnchorRange = highlightedAnchorRange
            self.onSelectionAction = onSelectionAction
            self.onHighlightedTextAction = onHighlightedTextAction
        }

        func updateCallbacks(
            onVisibleUTF16Location: @escaping (Int) -> Void,
            onScrollDirection: @escaping (ReaderCoordinator.ScrollDirection) -> Void,
            onBodyTap: @escaping () -> Void,
            onInitialScrollApplied: @escaping () -> Void,
            selectedText: @escaping (NSRange) -> String?,
            normalizedSelection: @escaping (NSRange) -> NSRange?,
            isStandaloneLayoutSelection: @escaping (NSRange) -> Bool,
            highlightedAnchorAt: @escaping (Int) -> TextAnchor?,
            highlightedAnchorIntersecting: @escaping (NSRange) -> TextAnchor?,
            highlightedAnchorRange: @escaping (TextAnchor) -> NSRange?,
            onSelectionAction: @escaping (NSRange, ReaderSelectionAction) -> Void,
            onHighlightedTextAction: @escaping (TextAnchor, ReaderSelectionAction) -> Void
        ) {
            self.onVisibleUTF16Location = onVisibleUTF16Location
            self.onScrollDirection = onScrollDirection
            self.onBodyTap = onBodyTap
            self.onInitialScrollApplied = onInitialScrollApplied
            self.selectedText = selectedText
            self.normalizedSelection = normalizedSelection
            self.isStandaloneLayoutSelection = isStandaloneLayoutSelection
            self.highlightedAnchorAt = highlightedAnchorAt
            self.highlightedAnchorIntersecting = highlightedAnchorIntersecting
            self.highlightedAnchorRange = highlightedAnchorRange
            self.onSelectionAction = onSelectionAction
            self.onHighlightedTextAction = onHighlightedTextAction
        }

        func requestScroll(_ request: ReaderScrollRequest, in textView: UITextView) {
            guard request != lastScrollRequest else { return }
            // An anchor route is authoritative. A prior attributed-text
            // update may have queued an async restoration of the old offset;
            // invalidate it before this request gets a chance to apply.
            documentOffsetRestoreToken += 1
            pendingScrollRequest = request
            applyPendingScrollIfReady(in: textView)
        }

        func beginDocumentOffsetRestore() -> Int {
            documentOffsetRestoreToken += 1
            return documentOffsetRestoreToken
        }

        func isCurrentDocumentOffsetRestore(_ token: Int) -> Bool {
            token == documentOffsetRestoreToken
        }

        func applyPendingScrollIfReady(in textView: UITextView) {
            guard let request = pendingScrollRequest,
                  textView.window != nil,
                  textView.bounds.width > 0,
                  textView.bounds.height > 0,
                  request.range.location <= textView.attributedText.length else {
                return
            }

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            layoutManager.ensureLayout(for: textContainer)
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: request.range,
                actualCharacterRange: nil
            )
            guard glyphRange.length > 0 else { return }

            let targetRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textContainer
            )
            let minimumOffset = -textView.adjustedContentInset.top
            let maximumOffset = max(
                minimumOffset,
                textView.contentSize.height
                    - textView.bounds.height
                    + textView.adjustedContentInset.bottom
            )
            // The document's text container begins below the 164pt top inset.
            // Moving the target glyph's document origin to the scroll origin
            // consequently places it exactly below reader chrome and blur.
            let targetOffset = min(max(targetRect.minY, minimumOffset), maximumOffset)

            isRestoringRange = true
            textView.setContentOffset(
                CGPoint(x: textView.contentOffset.x, y: targetOffset),
                animated: false
            )
            isRestoringRange = false
            lastScrollRequest = request
            pendingScrollRequest = nil
            onInitialScrollApplied()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !suppressHighlightedSelectionClear,
                  textView.selectedRange.length > 0 else { return }
            if isStandaloneLayoutSelection(textView.selectedRange) {
                // A paragraph spacer is a TextKit implementation detail. A
                // double-tap must not turn it into an independent selection,
                // although a real cross-paragraph drag may pass through it.
                cancelPendingNativeSelection(in: textView)
                return
            }
            if highlightedAnchorIntersecting(textView.selectedRange) != nil {
                // Existing highlights are immutable selections: users tap
                // them to open their asset menu instead of selecting again.
                // Checking range intersection (not only its first character)
                // also catches UIKit's word expansion from a double-tap.
                cancelPendingNativeSelection(in: textView)
                return
            }
            guard let normalized = normalizedSelection(textView.selectedRange),
                  normalized != textView.selectedRange else { return }
            // Transparent paragraph spacers are layout-only characters. If a
            // native selection endpoint lands on one, UIKit stretches its
            // handle through the entire gap. Keep endpoints on source text.
            suppressHighlightedSelectionClear = true
            textView.selectedRange = normalized
            suppressHighlightedSelectionClear = false
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            // UIKit can ask for the stock menu just after a double-tap, before
            // the selection-clear callback finishes. Titles and layout-only
            // paragraph gaps must never present it.
            guard !isStandaloneLayoutSelection(range) else { return nil }
            return ReaderSelectionMenu.makeMenu { [weak self, weak textView] action in
                guard let self, let textView, range.length > 0 else { return }
                if action == .copy {
                    UIPasteboard.general.string = self.selectedText(range)
                }
                self.onSelectionAction(range, action)
                self.clearSelection(in: textView)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset.y
            let isUserDriven = ReaderScrollEventClassifier.isUserDriven(
                isTracking: isUserScrollSession,
                isDragging: isUserScrollSession,
                isDecelerating: isUserScrollSession,
                isRestoringRange: isRestoringRange
            )
            if let direction = scrollClassifier.direction(for: offset, isUserDriven: isUserDriven) {
                onScrollDirection(direction)
            }

            guard isUserDriven else { return }

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

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserScrollSession = true
            clearSelectionIfNeeded(in: scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserScrollSession = false
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserScrollSession = false
        }

        @objc private func handleBodyTap() {
            guard bodyTapRecognizer.state == .ended,
                  let textView = bodyTapRecognizer.view as? UITextView else { return }
            if textView.selectedRange.length > 0 {
                clearSelection(in: textView)
                return
            }
            let touchPoint = bodyTapRecognizer.location(in: textView)
            let textPoint = CGPoint(
                x: touchPoint.x - textView.textContainerInset.left,
                y: touchPoint.y - textView.textContainerInset.top
            )
            let location = textView.layoutManager.characterIndex(
                for: textPoint,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            if let anchor = highlightedAnchorAt(location) {
                activeHighlightedAnchor = anchor
                highlightedTextMenu?.presentEditMenu(with: UIEditMenuConfiguration(
                    identifier: anchor.id as NSUUID,
                    sourcePoint: stableMenuSourcePoint(for: anchor, in: textView)
                ))
                return
            }
            onBodyTap()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if let textView = gestureRecognizer.view as? ReaderViewportTextView,
               touch.view?.isDescendant(of: textView.completionButton) == true {
                return false
            }
            // While a highlighted-asset menu is visible, the system should be
            // allowed to dismiss it on an outside tap without also forwarding
            // that same tap to reader chrome visibility.
            return activeHighlightedAnchor == nil
        }

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard let anchor = activeHighlightedAnchor else { return nil }
            return ReaderSelectionMenu.makeHighlightedMenu { [weak self] action in
                guard let self else { return }
                if action == .copy {
                    UIPasteboard.general.string = anchor.selectedText
                }
                self.onHighlightedTextAction(anchor, action)
            }
        }

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            willDismissMenuFor configuration: UIEditMenuConfiguration,
            animator: any UIEditMenuInteractionAnimating
        ) {
            activeHighlightedAnchor = nil
        }

        private func clearSelectionIfNeeded(in scrollView: UIScrollView) {
            guard let textView = scrollView as? UITextView,
                  textView.selectedRange.length > 0 else { return }
            clearSelection(in: textView)
        }

        private func clearSelection(in textView: UITextView) {
            // Collapsing the range removes the selected text or attachment,
            // and resigning first responder closes UIKit's contextual menu.
            textView.selectedRange = NSRange(location: textView.selectedRange.upperBound, length: 0)
            textView.resignFirstResponder()
        }

        private func cancelPendingNativeSelection(in textView: UITextView) {
            suppressHighlightedSelectionClear = true
            clearSelection(in: textView)
            // UIKit can schedule its stock edit menu after the delegate
            // callback for a double-tap. Briefly disabling selection cancels
            // that pending presentation before restoring normal selection.
            textView.isSelectable = false
            DispatchQueue.main.async {
                textView.isSelectable = true
            }
            suppressHighlightedSelectionClear = false
        }

        private func stableMenuSourcePoint(for anchor: TextAnchor, in textView: UITextView) -> CGPoint {
            guard let range = highlightedAnchorRange(anchor), range.length > 0 else {
                return bodyTapRecognizer.location(in: textView)
            }
            let firstGlyph = textView.layoutManager.glyphRange(
                forCharacterRange: NSRange(location: range.location, length: 1),
                actualCharacterRange: nil
            )
            let glyphRect = textView.layoutManager.boundingRect(
                forGlyphRange: firstGlyph,
                in: textView.textContainer
            )
            return CGPoint(
                x: glyphRect.midX + textView.textContainerInset.left,
                y: glyphRect.midY + textView.textContainerInset.top
            )
        }

    }
}

enum ReaderCompletionControlLayout {
    static let size: CGFloat = 47
    static let topSpacing: CGFloat = 36
    /// Keeps the completed-reading control in the scroll document while
    /// preserving the reader's original 122pt clearance below it.
    static let textContainerBottomInset: CGFloat = 205
}
