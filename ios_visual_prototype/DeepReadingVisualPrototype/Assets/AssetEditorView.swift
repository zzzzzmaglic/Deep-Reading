import SwiftUI
import UIKit

/// A single UIKit text renderer for both the editable and read-only card
/// states. `Text` and SwiftUI `TextEditor` apply different default insets and
/// leading, which made the linked-note card visibly change when toggling edit.
struct AssetEditorView: UIViewRepresentable {
    @ObservedObject var controller: AssetDraftController
    let width: CGFloat
    let height: CGFloat
    let focusRequest: Int
    let automaticallyFocus: Bool
    let textAlignment: NSTextAlignment
    let cursorPlacementRequest: Int

    init(
        controller: AssetDraftController,
        width: CGFloat = 305,
        height: CGFloat,
        focusRequest: Int,
        automaticallyFocus: Bool = true,
        textAlignment: NSTextAlignment = .left,
        cursorPlacementRequest: Int = 0
    ) {
        self.controller = controller
        self.width = width
        self.height = height
        self.focusRequest = focusRequest
        self.automaticallyFocus = automaticallyFocus
        self.textAlignment = textAlignment
        self.cursorPlacementRequest = cursorPlacementRequest
    }

    static func noteTextAlignment(hasAnchor: Bool) -> NSTextAlignment {
        hasAnchor ? .justified : .left
    }

    static func cursorRange(for content: String, placingAtEnd: Bool) -> NSRange {
        NSRange(
            location: placingAtEnd ? (content as NSString).length : 0,
            length: 0
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(setNoteContent: controller.setNoteContent)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInset = .zero
        textView.contentInsetAdjustmentBehavior = .never
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.accessibilityIdentifier = "asset-note-editor"
        configure(textView, content: controller.draft.noteContent ?? "")
        applyRequestedCursorPlacement(to: textView, coordinator: context.coordinator)
        return textView
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        CGSize(width: width, height: height)
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.setNoteContent = controller.setNoteContent
        configure(textView, content: controller.draft.noteContent ?? "")
        applyRequestedCursorPlacement(to: textView, coordinator: context.coordinator)

        guard automaticallyFocus,
              context.coordinator.lastFocusRequest != focusRequest else {
            return
        }
        context.coordinator.lastFocusRequest = focusRequest
        DispatchQueue.main.async {
            guard textView.window != nil else { return }
            textView.becomeFirstResponder()
        }
    }

    private func configure(_ textView: UITextView, content: String) {
        let attributes = textAttributes
        let previousSelection = textView.selectedRange
        textView.textAlignment = textAlignment
        if textView.text != content || currentTextAlignment(of: textView) != textAlignment {
            textView.attributedText = NSAttributedString(string: content, attributes: attributes)
            textView.selectedRange = NSRange(
                location: min(previousSelection.location, (content as NSString).length),
                length: 0
            )
        }
        textView.typingAttributes = attributes
        textView.isEditable = automaticallyFocus
        textView.isSelectable = automaticallyFocus
        textView.isUserInteractionEnabled = automaticallyFocus
    }

    private func applyRequestedCursorPlacement(
        to textView: UITextView,
        coordinator: Coordinator
    ) {
        guard cursorPlacementRequest > 0,
              coordinator.lastCursorPlacementRequest != cursorPlacementRequest else {
            return
        }
        coordinator.lastCursorPlacementRequest = cursorPlacementRequest
        textView.selectedRange = Self.cursorRange(
            for: textView.text,
            placingAtEnd: true
        )
    }

    private func currentTextAlignment(of textView: UITextView) -> NSTextAlignment? {
        guard textView.attributedText.length > 0 else { return textView.textAlignment }
        return (textView.attributedText.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle)?.alignment
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = ReadingAssetCardContentLayout.noteLineHeight
        paragraphStyle.maximumLineHeight = ReadingAssetCardContentLayout.noteLineHeight
        paragraphStyle.alignment = textAlignment
        return [
            .font: UIFont.systemFont(ofSize: ReadingAssetCardContentLayout.textSize),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var setNoteContent: (String) -> Void
        var lastFocusRequest: Int?
        var lastCursorPlacementRequest: Int?

        init(setNoteContent: @escaping (String) -> Void) {
            self.setNoteContent = setNoteContent
        }

        func textViewDidChange(_ textView: UITextView) {
            setNoteContent(textView.text)
        }
    }
}
