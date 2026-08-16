import Combine
import Foundation

struct ReaderDependencies: @unchecked Sendable {
    let articleRepository: any ArticleRepository
    let readingAssetRepository: any ReadingAssetRepository
}

enum ReaderCoordinatorFailure: LocalizedError, Equatable {
    case loadFailed
    case progressFailed
    case assetsFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed: "无法加载文章，请重试。"
        case .progressFailed: "阅读进度未保存。"
        case .assetsFailed: "标注未能刷新。"
        }
    }
}

@MainActor
final class ReaderCoordinator: ObservableObject {
    enum ScrollDirection { case up, down }

    @Published private(set) var article: Article?
    @Published private(set) var assets: [ReadingAsset] = []
    @Published private(set) var initialPosition: ReaderPosition?
    @Published private(set) var chromeIsVisible = true
    @Published private(set) var loadFailure: ReaderCoordinatorFailure?
    @Published private(set) var progressFailure: ReaderCoordinatorFailure?
    @Published private(set) var assetFailure: ReaderCoordinatorFailure?

    private let dependencies: ReaderDependencies
    private let progressDebounce: Duration
    private let chromeHideDelay: Duration
    private var layout: ReaderTextLayout?
    private var lastRoute: ReaderRoute?
    private var lastQueuedPosition: ReaderPosition?
    private var progressTask: Task<Void, Never>?
    private var chromeTask: Task<Void, Never>?

    init(
        dependencies: ReaderDependencies,
        progressDebounce: Duration = .milliseconds(350),
        chromeHideDelay: Duration = .milliseconds(350)
    ) {
        self.dependencies = dependencies
        self.progressDebounce = progressDebounce
        self.chromeHideDelay = chromeHideDelay
    }

    deinit {
        progressTask?.cancel()
        chromeTask?.cancel()
    }

    func load(route: ReaderRoute) async throws {
        loadFailure = nil
        assetFailure = nil
        lastRoute = route
        do {
            let article = try await dependencies.articleRepository.readArticle(id: route.articleID)
            self.article = article
            layout = ReaderTextLayout(article: article, image: nil)

            // Persisted progress is deliberately read before route state is resolved.
            let persistedProgress = try await dependencies.articleRepository.readProgress(articleID: route.articleID)
            let assets: [ReadingAsset]
            do {
                assets = try await dependencies.readingAssetRepository.readAssets(articleID: route.articleID)
            } catch {
                assets = []
                assetFailure = .assetsFailed
            }
            self.assets = assets

            if let anchorID = route.anchorID,
               let anchor = assets.first(where: { $0.anchor?.id == anchorID })?.anchor {
                initialPosition = ReaderPosition(
                    blockID: anchor.startBlockID,
                    utf16Offset: anchor.startUTF16Offset
                )
            } else {
                initialPosition = persistedProgress
            }
        } catch {
            loadFailure = .loadFailed
            throw error
        }
    }

    func handleScroll(direction: ScrollDirection) {
        switch direction {
        case .down:
            chromeTask?.cancel()
            chromeTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.chromeHideDelay)
                guard !Task.isCancelled else { return }
                self.hideChrome()
            }
        case .up:
            showChrome()
        }
    }

    func handleBodyTap() {
        if chromeIsVisible { return }
        showChrome()
    }

    func queueProgress(visibleUTF16Location: Int) {
        guard let article, let layout else { return }
        let position = layout.position(forVisibleUTF16Location: visibleUTF16Location)
        guard position.blockID != nil else { return }
        lastQueuedPosition = position
        progressTask?.cancel()
        progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.progressDebounce)
            guard !Task.isCancelled else { return }
            do {
                try await self.dependencies.readingAssetRepository.upsertReadingProgress(
                    articleID: article.id,
                    position: position
                )
                self.progressFailure = nil
            } catch {
                self.progressFailure = .progressFailed
            }
        }
    }

    func showChrome() {
        chromeTask?.cancel()
        chromeIsVisible = true
    }

    func hideChrome() {
        chromeTask?.cancel()
        chromeIsVisible = false
    }

    func refreshAssets() async {
        guard let article else { return }
        do {
            assets = try await dependencies.readingAssetRepository.readAssets(articleID: article.id)
            assetFailure = nil
        } catch {
            assetFailure = .assetsFailed
        }
    }

    func retryLoad() {
        guard let lastRoute else { return }
        Task { @MainActor [weak self] in
            try? await self?.load(route: lastRoute)
        }
    }

    func retryProgress() {
        guard let lastQueuedPosition, let article else { return }
        progressTask?.cancel()
        progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.readingAssetRepository.upsertReadingProgress(
                    articleID: article.id,
                    position: lastQueuedPosition
                )
                self.progressFailure = nil
            } catch {
                self.progressFailure = .progressFailed
            }
        }
    }
}
