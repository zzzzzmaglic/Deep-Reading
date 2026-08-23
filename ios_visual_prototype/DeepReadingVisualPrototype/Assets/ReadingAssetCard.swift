import SwiftUI
import UIKit

struct ReadingAssetCardContentLayout: Equatable {
    let width: CGFloat
    let height: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let lineLimit: Int?

    // Figma 06c uses the same 14 pt body face in the quote and note areas.
    static let textSize: CGFloat = 14
    static let quoteLineHeight: CGFloat = 24
    static let noteLineHeight: CGFloat = 20
    static let cardHeight: CGFloat = 400
    static let actionRowY: CGFloat = 337

    // Figma 06c — the grey quote card is deliberately almost edge-to-edge
    // within the 345 pt asset card, while its text has a separate inset.
    static let linkedQuoteBackground = ReadingAssetCardContentLayout(
        width: 323,
        height: 93,
        xOffset: 11,
        yOffset: 11,
        lineLimit: nil
    )

    static let linkedQuoteText = ReadingAssetCardContentLayout(
        width: 294,
        height: 76,
        xOffset: 25.5,
        yOffset: 25,
        lineLimit: 3
    )

    // User-approved linked-note edit-state optical adjustment. The quote
    // background intentionally stays at the Figma 06c position above.
    static let linkedQuoteTextEditing = ReadingAssetCardContentLayout(
        width: 294,
        height: 76,
        xOffset: 25.5,
        yOffset: 25,
        lineLimit: 3
    )

    static let standaloneNote = ReadingAssetCardContentLayout(
        width: 305,
        height: 310,
        xOffset: 20,
        yOffset: 24,
        lineLimit: nil
    )

    // Read-only linked note geometry from Figma 06c.
    static let linkedNote = ReadingAssetCardContentLayout(
        width: 308,
        height: 220,
        xOffset: 18.5,
        yOffset: 116,
        lineLimit: nil
    )

    // The editable linked-note viewport has the same size, with the user's
    // requested 2 pt optical downward adjustment.
    static let linkedNoteEditing = ReadingAssetCardContentLayout(
        width: 308,
        height: 220,
        xOffset: 18.5,
        yOffset: 116,
        lineLimit: nil
    )

    static func lineSpacing(for lineHeight: CGFloat) -> CGFloat {
        max(0, lineHeight - UIFont.systemFont(ofSize: textSize).lineHeight)
    }
}

struct ReadingAssetCard: View {
    let token: Int
    let originalChromeState: ReaderChromeState
    let close: (Int, ReaderChromeState) -> Void

    @StateObject private var controller: AssetDraftController
    @State private var isEditing: Bool
    @State private var presentsTags = false
    @State private var presentsDeleteConfirmation = false
    @State private var presentsDiscardConfirmation = false
    @State private var errorMessage: String?
    @State private var keyboardHeight: CGFloat = 0
    @State private var noteFocusRequest = 0
    @State private var cursorPlacementRequest = 0

    static func quoteDisplayText(_ text: String) -> String {
        text
    }

    static func quoteTextLayout(
        isEditing: Bool,
        hasAnchor: Bool
    ) -> ReadingAssetCardContentLayout {
        guard hasAnchor else {
            return ReadingAssetCardContentLayout.linkedQuoteText
        }
        return isEditing
            ? ReadingAssetCardContentLayout.linkedQuoteTextEditing
            : ReadingAssetCardContentLayout.linkedQuoteText
    }

    static func placeholderNoteLayout(hasAnchor: Bool) -> ReadingAssetCardContentLayout {
        guard hasAnchor else {
            return ReadingAssetCardContentLayout.standaloneNote
        }
        let note = ReadingAssetCardContentLayout.linkedNote
        return ReadingAssetCardContentLayout(
            width: note.width,
            height: ReadingAssetCardContentLayout.noteLineHeight,
            xOffset: note.xOffset,
            yOffset: note.yOffset,
            lineLimit: 1
        )
    }

    init(
        draft: AssetDraft,
        repository: any ReadingAssetRepository,
        token: Int,
        originalChromeState: ReaderChromeState,
        initiallyPresentsTags: Bool = false,
        close: @escaping (Int, ReaderChromeState) -> Void,
        onSuccessfulSave: @escaping () -> Void,
        onSuccessfulDelete: @escaping (UUID) -> Void,
        onSuccessfulTagUpdate: @escaping () -> Void
    ) {
        self.token = token
        self.originalChromeState = originalChromeState
        self.close = close
        _isEditing = State(initialValue: draft.asset == nil)
        _presentsTags = State(initialValue: initiallyPresentsTags)
        _controller = StateObject(wrappedValue: AssetDraftController(
            draft: draft,
            repository: repository,
            isEditing: draft.asset == nil,
            onSuccessfulSave: onSuccessfulSave,
            onSuccessfulDelete: onSuccessfulDelete,
            onSuccessfulTagUpdate: onSuccessfulTagUpdate
        ))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !controller.isMutationInFlight else { return }
                    requestClose()
                }

            Button(action: requestClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭标注卡片")
            .accessibilityIdentifier("asset-card-dismiss")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 24)
            .padding(.top, 84)

            card
                .padding(.horizontal, 24)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { value in
                            if value.translation.height > 56, !controller.isMutationInFlight {
                                requestClose()
                            }
                        }
                )

            if presentsTags {
                TagManagementSheet(
                    controller: controller,
                    isEditing: isEditing,
                    dismiss: { presentsTags = false }
                )
            }

        }
        .accessibilityIdentifier("reading-asset-card")
        .task { await controller.loadAvailableTags(ensuring: debugDemoTagNames) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardHeight = max(0, UIScreen.main.bounds.height - frame.minY)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .alert("确认删除该阅读资产？", isPresented: $presentsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive, action: deleteAsset)
                .accessibilityIdentifier("asset-delete-confirm")
        } message: {
            Text("删除后将无法恢复。")
        }
        .alert("放弃本次编辑？", isPresented: $presentsDiscardConfirmation) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃编辑", role: .destructive) {
                guard !controller.isMutationInFlight else { return }
                controller.discard()
                close(token, originalChromeState)
            }
            .accessibilityIdentifier("asset-discard-confirm")
        } message: {
            Text("未保存的笔记内容将不会被保留。")
        }
    }

    private var card: some View {
        ZStack(alignment: .topLeading) {
            if let quote = controller.draft.anchor?.selectedText {
                let backgroundLayout = ReadingAssetCardContentLayout.linkedQuoteBackground
                let quoteLayout = Self.quoteTextLayout(
                    isEditing: isEditing,
                    hasAnchor: controller.draft.anchor != nil
                )
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemGroupedBackground))
                    .frame(width: backgroundLayout.width, height: backgroundLayout.height)
                    .offset(x: backgroundLayout.xOffset, y: backgroundLayout.yOffset)

                Text(Self.quoteDisplayText(quote))
                    .font(.system(size: ReadingAssetCardContentLayout.textSize))
                    .lineSpacing(
                        ReadingAssetCardContentLayout.lineSpacing(
                            for: ReadingAssetCardContentLayout.quoteLineHeight
                        )
                    )
                    .lineLimit(quoteLayout.lineLimit)
                    .frame(width: quoteLayout.width, height: quoteLayout.height, alignment: .topLeading)
                    .offset(x: quoteLayout.xOffset, y: quoteLayout.yOffset)
            }

            if isEditing {
                let noteLayout = controller.draft.anchor == nil
                    ? ReadingAssetCardContentLayout.standaloneNote
                    : usesLinkedNoteEditingGeometry
                        ? ReadingAssetCardContentLayout.linkedNoteEditing
                        : ReadingAssetCardContentLayout.linkedNote
                AssetEditorView(
                    controller: controller,
                    width: noteLayout.width,
                    height: noteLayout.height,
                    focusRequest: noteFocusRequest,
                    textAlignment: AssetEditorView.noteTextAlignment(
                        hasAnchor: controller.draft.anchor != nil
                    ),
                    cursorPlacementRequest: cursorPlacementRequest
                )
                .offset(x: noteLayout.xOffset, y: noteLayout.yOffset)
            } else if let noteContent = controller.draft.noteContent,
                      !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if controller.draft.anchor == nil {
                    let noteLayout = ReadingAssetCardContentLayout.standaloneNote
                    AssetEditorView(
                        controller: controller,
                        width: noteLayout.width,
                        height: noteLayout.height,
                        focusRequest: noteFocusRequest,
                        automaticallyFocus: false,
                        cursorPlacementRequest: cursorPlacementRequest
                    )
                    .allowsHitTesting(false)
                    .offset(x: noteLayout.xOffset, y: noteLayout.yOffset)
                } else {
                    // Use the exact same editor geometry and text renderer as
                    // edit state so a linked-note card does not jump or change
                    // typography while switching modes.
                    let noteLayout = ReadingAssetCardContentLayout.linkedNote
                    AssetEditorView(
                        controller: controller,
                        width: noteLayout.width,
                        height: noteLayout.height,
                        focusRequest: noteFocusRequest,
                        automaticallyFocus: false,
                        textAlignment: AssetEditorView.noteTextAlignment(hasAnchor: true),
                        cursorPlacementRequest: cursorPlacementRequest
                    )
                    .allowsHitTesting(false)
                    .offset(x: noteLayout.xOffset, y: noteLayout.yOffset)
                }
            } else {
                let placeholderLayout = Self.placeholderNoteLayout(
                    hasAnchor: controller.draft.anchor != nil
                )
                Button("添加笔记内容", action: beginEditing)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: placeholderLayout.width,
                        height: placeholderLayout.height,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                    .offset(x: placeholderLayout.xOffset, y: placeholderLayout.yOffset)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .offset(x: 20, y: 118)
            }

            Button("#标签") {
                    resignFirstResponder()
                    presentsTags = true
                }
                .font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44, alignment: .leading)
                .offset(x: 20, y: actionRowY)

            Button(role: .destructive, action: activateDelete) {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
            }
            .offset(x: 64, y: actionRowY)

            Button(action: saveOrBeginEditing) {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .frame(width: 44, height: 44)
                    .background(Color.blue, in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("asset-save")
            .offset(x: 282, y: ReadingAssetCardContentLayout.actionRowY)
        }
        .frame(width: 345, height: cardHeight, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 28))
        .disabled(controller.isMutationInFlight)
        .offset(y: cardVerticalOffset)
        .animation(.easeOut(duration: 0.22), value: cardVerticalOffset)
    }

    private func requestClose() {
        guard !controller.isMutationInFlight else { return }
        switch controller.dismissalDecision {
        case .close:
            close(token, originalChromeState)
        case .confirmDiscard:
            let keyboardWasVisible = keyboardHeight > 0
            presentsDiscardConfirmation = true
            restoreEditorFocusIfNeeded(keyboardWasVisible)
        }
    }

    private func saveOrBeginEditing() {
        guard !controller.isMutationInFlight else { return }
        guard isEditing else {
            beginEditing()
            return
        }
        Task {
            do {
                try await controller.save()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteAsset() {
        guard !controller.isMutationInFlight else { return }
        Task {
            do {
                try await controller.delete()
                errorMessage = nil
            } catch {
                errorMessage = "删除失败，请稍后重试"
                presentsDeleteConfirmation = false
            }
        }
    }

    private func activateDelete() {
        guard !controller.isMutationInFlight else { return }
        guard controller.draft.assetID != nil else {
            requestClose()
            return
        }
        let keyboardWasVisible = keyboardHeight > 0
        presentsDeleteConfirmation = true
        restoreEditorFocusIfNeeded(keyboardWasVisible)
    }

    private func restoreEditorFocusIfNeeded(_ keyboardWasVisible: Bool) {
        guard keyboardWasVisible, isEditing else { return }
        DispatchQueue.main.async {
            noteFocusRequest &+= 1
        }
    }

    private func beginEditing() {
        cursorPlacementRequest &+= 1
        isEditing = true
        controller.setEditing(true)
    }

    private func resignFirstResponder() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var debugDemoTagNames: [String] {
        #if DEBUG
        ["产品灵感", "决策框架", "人物", "商业化", "时间管理", "写作练习", "长期主义"]
        #else
        []
        #endif
    }

    private var cardHeight: CGFloat { ReadingAssetCardContentLayout.cardHeight }

    private var actionRowY: CGFloat { ReadingAssetCardContentLayout.actionRowY }

    private var usesLinkedNoteEditingGeometry: Bool {
        isEditing && controller.draft.asset?.kind == .linkedNote
    }

    private var cardVerticalOffset: CGFloat {
        guard isEditing else { return 0 }
        if keyboardHeight > 0 {
            // Keep a 16pt gap between the 400pt card and the live keyboard,
            // matching Figma 06b/06c on the iPhone 16 canvas.
            return (UIScreen.main.bounds.height - cardHeight) / 2 - keyboardHeight - 16
        }
        // Confirmations preserve the exact keyboard state that existed when
        // they appeared. With no keyboard, the card therefore stays put.
        return 0
    }
}
