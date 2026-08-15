import SwiftUI

#if DEBUG

struct ReaderPrototypeView: View {
    @State private var state: ReaderPrototypeState

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let frameIndex = arguments.firstIndex(of: "--reader-frame")
        let frameName = frameIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        _state = State(initialValue: ReaderPrototypeState.preview(frameName: frameName))
    }

    var body: some View {
        ZStack {
            ReaderVisualTokens.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.article.title)
                        .font(.system(size: ReaderVisualTokens.titleSize, weight: .medium))
                        .foregroundStyle(ReaderVisualTokens.primaryText)
                        .padding(.top, 116)
                        .padding(.bottom, 28)

                    ForEach(state.article.blocks) { block in
                        blockView(block)
                    }
                }
                .padding(.horizontal, ReaderVisualTokens.horizontalInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 122)
                .contentShape(Rectangle())
                .onTapGesture { revealControls() }
                .onLongPressGesture { show(.textSelection) }
            }
            .ignoresSafeArea()
            .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                geometry.contentOffset.y
            }, action: { previousOffset, currentOffset in
                if currentOffset > previousOffset {
                    handleScroll(.down)
                } else if currentOffset < previousOffset {
                    handleScroll(.up)
                }
            })
            .overlay(alignment: .top) {
                ReaderTopProgressiveBlur(isVisible: state.readerChromeIsVisible)
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                ReaderTopGlassControls()
                    .opacity(state.readerChromeIsVisible ? 1 : 0)
                    .allowsHitTesting(state.readerChromeIsVisible)
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                if state.readerChromeIsVisible || state.aiControlIsVisible {
                    ReaderBottomGlassControls(
                        showsReaderChrome: state.readerChromeIsVisible,
                        showsAIControl: state.aiControlIsVisible,
                        showAssetCard: { show(.assetCard) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .scrollEdgeEffectHidden(true, for: .top)
            .scrollEdgeEffectHidden(!state.readerChromeIsVisible, for: .bottom)

            overlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.22), value: state.frame)
        .statusBarHidden(state.shouldHideStatusBar)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func blockView(_ block: PrototypeArticleBlock) -> some View {
        switch block.kind {
        case .paragraph:
            Text(block.text)
                .font(.system(size: ReaderVisualTokens.bodySize, weight: .regular))
                .foregroundStyle(ReaderVisualTokens.primaryText)
                .lineSpacing(ReaderVisualTokens.bodyLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, ReaderVisualTokens.paragraphSpacing)
        case .image:
            Image(block.imageName ?? "four_forces")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch state.frame {
        case .textSelection:
            ReaderSelectionOverlay(underline: { show(.highlighted) }, dismiss: { show(.focused) })
        case .highlighted:
            ReaderHighlightOverlay(openAsset: { show(.assetCard) })
        case .assetCard:
            ReaderAssetCardOverlay(isEditing: false, beginEditing: { show(.assetEditor) }, showTags: { show(.tagManager) }, dismiss: { show(.controlsVisible) })
        case .assetEditor:
            ReaderAssetCardOverlay(isEditing: true, beginEditing: { show(.assetEditor) }, showTags: { show(.tagManager) }, dismiss: { show(.controlsVisible) })
        case .tagManager:
            ReaderTagSheetOverlay(isNewTag: false, dismiss: { show(.assetCard) }, showNewTag: { show(.newTag) })
        case .newTag:
            ReaderTagSheetOverlay(isNewTag: true, dismiss: { show(.assetCard) }, showNewTag: { show(.newTag) })
        case .controlsVisible, .focused:
            EmptyView()
        }
    }

    private func revealControls() {
        withAnimation(.easeInOut(duration: 0.22)) {
            state.toggleReaderChrome()
        }
    }

    private func show(_ frame: ReaderFrame) {
        withAnimation(.easeInOut(duration: 0.22)) {
            state.show(frame)
        }
    }

    private func handleScroll(_ direction: ReaderScrollDirection) {
        withAnimation(.easeInOut(duration: 0.22)) {
            state.handleScroll(direction)
        }
    }
}
#endif
