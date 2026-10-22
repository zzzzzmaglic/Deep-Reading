import SwiftUI
import UIKit

/// The only production reader entry point. Preview fixtures remain isolated in
/// `ReaderPrototypeView` and are never selected by the app runtime.
struct ReaderScreen: View {
    let route: ReaderRoute
    let dependencies: ReaderDependencies
    let onOpenSummary: (ReaderRoute) -> Void
    let assetRefreshRevision: Int

    @StateObject private var coordinator: ReaderCoordinator

    private struct ViewportIdentity: Hashable {
        let route: ReaderRoute
        let scrollRequestRevision: Int
    }

    init(
        route: ReaderRoute,
        dependencies: ReaderDependencies,
        onOpenSummary: @escaping (ReaderRoute) -> Void = { _ in },
        assetRefreshRevision: Int = 0
    ) {
        self.route = route
        self.dependencies = dependencies
        self.onOpenSummary = onOpenSummary
        self.assetRefreshRevision = assetRefreshRevision
        _coordinator = StateObject(wrappedValue: ReaderCoordinator(dependencies: dependencies))
    }

    var body: some View {
        ZStack {
            Color(red: 0.973, green: 0.961, blue: 0.937)
                .ignoresSafeArea()

            if let article = coordinator.article {
                readerBody(article: article)
            } else if coordinator.loadFailure != nil {
                VStack(spacing: 14) {
                    Text("无法加载文章")
                        .font(.title3.weight(.semibold))
                    Button("重试") { coordinator.retryLoad() }
                        .buttonStyle(.borderedProminent)
                }
                .accessibilityIdentifier("reader-load-error")
            } else {
                ProgressView("正在加载文章…")
            }
        }
        // The whole reader—not just its UITextView—uses the full Figma canvas.
        // Overlay coordinates must therefore start at the physical top edge.
        .ignoresSafeArea()
        .task(id: route) {
            do {
                try await coordinator.load(route: route)
                #if DEBUG
                await coordinator.seedHighlightForUITestIfRequested()
                #endif
            } catch {
                // The coordinator owns the retryable rendered error state.
            }
        }
        .statusBarHidden(!coordinator.chromeIsVisible)
        .navigationTitle("每日推文")
        .toolbarTitleDisplayMode(.inline)
        .toolbar(coordinator.chromeIsVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onOpenSummary(route)
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .disabled(!coordinator.uiTestHighlightSeedIsReady)
                .accessibilityLabel("标注与笔记")
                .accessibilityIdentifier("reader-open-summary")
            }
        }
        .preferredColorScheme(.light)
        .readingAssetCardPresentation(item: assetCardPresentation) { presentation in
            ReadingAssetCard(
                draft: presentation.draft,
                repository: dependencies.readingAssetRepository,
                token: presentation.token,
                originalChromeState: presentation.originalChromeState,
                initiallyPresentsTags: presentation.initiallyPresentsTags,
                showsBackdrop: false,
                close: { token, chromeState in
                    coordinator.dismissAssetCard(token: token, restoring: chromeState)
                },
                onSuccessfulSave: {
                    coordinator.completeAssetCardSave(
                        token: presentation.token,
                        restoring: presentation.originalChromeState
                    )
                },
                onSuccessfulDelete: { assetID in
                    coordinator.completeAssetCardDelete(
                        assetID,
                        token: presentation.token,
                        restoring: presentation.originalChromeState
                    )
                },
                onSuccessfulTagUpdate: {
                    coordinator.completeAssetCardTagUpdate(token: presentation.token)
                }
            )
            .id(presentation.token)
            .ignoresSafeArea()
        }
        .task(id: assetRefreshRevision) {
            guard assetRefreshRevision > 0 else { return }
            await coordinator.refreshAssets()
        }
    }

    @ViewBuilder
    private func readerBody(article: Article) -> some View {
        let layout = ReaderTextLayout(article: article, image: UIImage(named: "FourForces"))
        let highlights = coordinator.assets.compactMap { $0.anchor }
        let requestedScrollRequest = coordinator.initialPosition.flatMap { position in
            layout.range(for: position).map { range in
                ReaderScrollRequest(route: route, range: range)
            }
        }

        ReaderTextView(
            layout: layout,
            highlights: highlights,
            documentRevision: ReaderTextDocumentRevision(
                articleID: article.id,
                contentChecksum: article.contentChecksum,
                highlights: highlights
            ),
            requestedScrollRequest: requestedScrollRequest,
            onVisibleUTF16Location: coordinator.queueProgress,
            onScrollDirection: coordinator.handleScroll,
            onBodyTap: coordinator.handleBodyTap,
            onInitialScrollApplied: coordinator.consumeInitialPosition,
            selectedText: { try? layout.selectedText(for: $0) },
            normalizedSelection: layout.normalizedSourceSelection,
            isStandaloneLayoutSelection: layout.isStandaloneLayoutSelection,
            highlightedAnchorAt: { location in
                layout.highlightedAnchor(at: location, among: highlights)
            },
            highlightedAnchorIntersecting: { selection in
                layout.highlightedAnchor(intersecting: selection, among: highlights)
            },
            highlightedAnchorRange: { anchor in
                try? layout.range(for: anchor)
            },
            onSelectionAction: { selection, action in
                Task { @MainActor in
                    do {
                        try await coordinator.performSelection(selection, action: action)
                    } catch {
                        coordinator.recordSelectionFailure(for: action)
                    }
                }
            },
            onHighlightedTextAction: { anchor, action in
                Task { @MainActor in
                    await coordinator.performHighlightedTextAction(anchor, action: action)
                }
            },
            showsBottomEdgeEffect: coordinator.chromeIsVisible
        )
        .id(ViewportIdentity(
            route: route,
            scrollRequestRevision: coordinator.scrollRequestRevision
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Keep the text viewport and bottom controls on the full-screen reader
        // canvas. The system navigation bar owns the top chrome and its inset.
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            ReaderBottomScrollEdgeContainer(
                showsReaderChrome: coordinator.chromeIsVisible,
                showsAIControl: true,
                showAssetCard: { _ = coordinator.beginStandaloneNote() }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 80)
        }
        .overlay(alignment: .bottom) {
            if coordinator.progressFailure != nil || coordinator.selectionFailure != nil || coordinator.assetFailure != nil {
                HStack(spacing: 10) {
                    if coordinator.selectionFailure == .invalidSelection {
                        Text("请选择正文后再划线")
                    } else {
                        Text(
                            coordinator.progressFailure != nil
                                ? "阅读进度未保存"
                                : coordinator.selectionFailure != nil
                                    ? "划线未创建"
                                    : "标注未能刷新"
                        )
                        Button("重试") {
                            if coordinator.progressFailure != nil {
                                coordinator.retryProgress()
                            } else if coordinator.selectionFailure != nil {
                                coordinator.retryHighlightCreation()
                            } else {
                                Task { await coordinator.refreshAssets() }
                            }
                        }
                    }
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 104)
                .accessibilityIdentifier(
                    coordinator.progressFailure != nil
                        ? "reader-progress-retry"
                        : coordinator.selectionFailure != nil
                            ? "reader-highlight-retry"
                            : "reader-assets-retry"
                )
            }
        }
        .animation(.easeInOut(duration: 0.22), value: coordinator.chromeIsVisible)
    }

    private var assetCardPresentation: Binding<ReadingAssetCardPresentation?> {
        Binding(
            get: {
                guard let draft = coordinator.presentedAssetDraft,
                      let chromeState = coordinator.assetCardChromeState,
                      let token = coordinator.assetCardToken else { return nil }
                return ReadingAssetCardPresentation(
                    draft: draft,
                    token: token,
                    originalChromeState: chromeState,
                    initiallyPresentsTags: coordinator.assetCardPresentsTags
                )
            },
            set: { presentation in
                guard presentation == nil,
                      let token = coordinator.assetCardToken,
                      let chromeState = coordinator.assetCardChromeState else { return }
                coordinator.dismissAssetCard(token: token, restoring: chromeState)
            }
        )
    }

}

extension ReaderRoute {
    /// The immutable local Supabase seed article, not a reader fixture.
    static let localSeed = ReaderRoute(
        articleID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        anchorID: nil,
        origin: .feed
    )
}
