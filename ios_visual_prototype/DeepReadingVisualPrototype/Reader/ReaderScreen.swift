import SwiftUI
import UIKit

/// The only production reader entry point. Preview fixtures remain isolated in
/// `ReaderPrototypeView` and are never selected by the app runtime.
struct ReaderScreen: View {
    let route: ReaderRoute
    let dependencies: ReaderDependencies
    let onOpenSummary: (ReaderRoute) -> Void
    let onBack: (ReaderOrigin) -> Void
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
        onBack: @escaping (ReaderOrigin) -> Void = { _ in },
        assetRefreshRevision: Int = 0
    ) {
        self.route = route
        self.dependencies = dependencies
        self.onOpenSummary = onOpenSummary
        self.onBack = onBack
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
        .preferredColorScheme(.light)
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
            }
        )
        .id(ViewportIdentity(
            route: route,
            scrollRequestRevision: coordinator.scrollRequestRevision
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The approved reader geometry is expressed against the full
        // 393 × 852 iPhone 16 canvas, not the post-status-bar safe area.
        // This mirrors the prior visual prototype and keeps the fixed chrome
        // at top y=52 / bottom y=780 rather than pulling it toward center.
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            topProgressiveEdge
        }
        .overlay(alignment: .top) {
            ReaderTopGlassControls(
                onBack: { onBack(route.origin) },
                onOpenSummary: { onOpenSummary(route) },
                isSummaryEnabled: coordinator.uiTestHighlightSeedIsReady
            )
                .opacity(coordinator.chromeIsVisible ? 1 : 0)
                .allowsHitTesting(coordinator.chromeIsVisible)
        }
        .overlay(alignment: .bottom) {
            ReaderBottomSoftEdge(isVisible: coordinator.chromeIsVisible)
        }
        .overlay(alignment: .bottom) {
            ReaderBottomGlassControls(
                showsReaderChrome: coordinator.chromeIsVisible,
                showsAIControl: true,
                showAssetCard: { _ = coordinator.beginStandaloneNote() }
            )
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
        .overlay {
            if let draft = coordinator.presentedAssetDraft,
               let chromeState = coordinator.assetCardChromeState,
               let token = coordinator.assetCardToken {
                ReadingAssetCard(
                    draft: draft,
                    repository: dependencies.readingAssetRepository,
                    token: token,
                    originalChromeState: chromeState,
                    initiallyPresentsTags: coordinator.assetCardPresentsTags,
                    close: { token, chromeState in
                        coordinator.dismissAssetCard(token: token, restoring: chromeState)
                    },
                    onSuccessfulSave: {
                        coordinator.completeAssetCardSave(token: token, restoring: chromeState)
                    },
                    onSuccessfulDelete: { assetID in
                        coordinator.completeAssetCardDelete(assetID, token: token, restoring: chromeState)
                    },
                    onSuccessfulTagUpdate: {
                        coordinator.completeAssetCardTagUpdate(token: token)
                    }
                )
                .id(token)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: coordinator.chromeIsVisible)
    }

    @ViewBuilder
    private var topProgressiveEdge: some View {
        #if DEBUG
        ReaderTopProgressiveBlur(isVisible: coordinator.chromeIsVisible)
        #else
        LinearGradient(
            colors: [Color(uiColor: .systemBackground).opacity(0.52), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 148)
        .allowsHitTesting(false)
        .opacity(coordinator.chromeIsVisible ? 1 : 0)
        #endif
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
