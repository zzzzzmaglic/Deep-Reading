import SwiftUI
import UIKit

/// The only production reader entry point. Preview fixtures remain isolated in
/// `ReaderPrototypeView` and are never selected by the app runtime.
struct ReaderScreen: View {
    let route: ReaderRoute
    let dependencies: ReaderDependencies

    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator: ReaderCoordinator

    init(route: ReaderRoute, dependencies: ReaderDependencies) {
        self.route = route
        self.dependencies = dependencies
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
        .task(id: route) {
            do {
                try await coordinator.load(route: route)
            } catch {
                // The coordinator owns the retryable rendered error state.
            }
        }
        .statusBarHidden(!coordinator.chromeIsVisible)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func readerBody(article: Article) -> some View {
        let layout = ReaderTextLayout(article: article, image: UIImage(named: "FourForces"))
        let highlights = coordinator.assets.compactMap { $0.anchor }
        let requestedRange = coordinator.initialPosition.flatMap { layout.range(for: $0) }

        ReaderTextView(
            layout: layout,
            highlights: highlights,
            documentRevision: ReaderTextDocumentRevision(
                articleID: article.id,
                contentChecksum: article.contentChecksum,
                highlights: highlights
            ),
            requestedScrollRange: requestedRange,
            onVisibleUTF16Location: coordinator.queueProgress,
            onScrollDirection: coordinator.handleScroll,
            onBodyTap: coordinator.handleBodyTap
        )
        .overlay(alignment: .top) {
            topProgressiveEdge
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            ReaderTopGlassControls(onBack: dismiss.callAsFunction)
                .opacity(coordinator.chromeIsVisible ? 1 : 0)
                .allowsHitTesting(coordinator.chromeIsVisible)
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if coordinator.chromeIsVisible {
                ReaderBottomGlassControls(
                    showsReaderChrome: true,
                    showsAIControl: true,
                    showAssetCard: {}
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .scrollEdgeEffectHidden(true, for: .top)
        .scrollEdgeEffectHidden(!coordinator.chromeIsVisible, for: .bottom)
        .overlay(alignment: .bottom) {
            if coordinator.progressFailure != nil || coordinator.assetFailure != nil {
                HStack(spacing: 10) {
                    Text(coordinator.progressFailure != nil ? "阅读进度未保存" : "标注未能刷新")
                    Button("重试") {
                        if coordinator.progressFailure != nil {
                            coordinator.retryProgress()
                        } else {
                            Task { await coordinator.refreshAssets() }
                        }
                    }
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 104)
                .accessibilityIdentifier(
                    coordinator.progressFailure != nil ? "reader-progress-retry" : "reader-assets-retry"
                )
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
