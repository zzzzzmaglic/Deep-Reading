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
    private var assetTask: Task<Void, Never>?
    private var chromeTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var progressGeneration = 0

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
        assetTask?.cancel()
        chromeTask?.cancel()
    }

    func load(route: ReaderRoute) async throws {
        loadGeneration += 1
        let generation = loadGeneration
        progressGeneration += 1
        progressTask?.cancel()
        assetTask?.cancel()
        loadFailure = nil
        assetFailure = nil
        lastRoute = route
        do {
            let article = try await dependencies.articleRepository.readArticle(id: route.articleID)
            guard isCurrentLoad(generation) else { return }
            self.article = article
            layout = ReaderTextLayout(article: article, image: nil)

            let persistedProgress = try await dependencies.articleRepository.readProgress(articleID: route.articleID)
            guard isCurrentLoad(generation) else { return }

            guard let anchorID = route.anchorID else {
                // A normal reader route renders restored progress before assets finish.
                initialPosition = persistedProgress
                loadAssets(articleID: route.articleID, generation: generation)
                return
            }

            do {
                let assets = try await dependencies.readingAssetRepository.readAssets(articleID: route.articleID)
                guard isCurrentLoad(generation) else { return }
                self.assets = assets
                if let anchor = assets.first(where: { $0.anchor?.id == anchorID })?.anchor {
                    initialPosition = ReaderPosition(
                        blockID: anchor.startBlockID,
                        utf16Offset: anchor.startUTF16Offset
                    )
                } else {
                    initialPosition = persistedProgress
                }
            } catch {
                guard isCurrentLoad(generation) else { return }
                assetFailure = .assetsFailed
                initialPosition = persistedProgress
            }
        } catch {
            guard isCurrentLoad(generation) else { return }
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
        progressGeneration += 1
        let generation = progressGeneration
        progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.progressDebounce)
            guard !Task.isCancelled, self.isCurrentProgress(generation) else { return }
            do {
                try await self.dependencies.readingAssetRepository.upsertReadingProgress(
                    articleID: article.id,
                    position: position
                )
                guard self.isCurrentProgress(generation) else { return }
                if self.progressFailure != nil {
                    self.progressFailure = nil
                }
            } catch {
                guard self.isCurrentProgress(generation) else { return }
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
        let generation = loadGeneration
        do {
            let loadedAssets = try await dependencies.readingAssetRepository.readAssets(articleID: article.id)
            guard isCurrentLoad(generation), self.article?.id == article.id else { return }
            assets = loadedAssets
            assetFailure = nil
        } catch {
            guard isCurrentLoad(generation), self.article?.id == article.id else { return }
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
        progressGeneration += 1
        let generation = progressGeneration
        progressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.readingAssetRepository.upsertReadingProgress(
                    articleID: article.id,
                    position: lastQueuedPosition
                )
                guard self.isCurrentProgress(generation) else { return }
                self.progressFailure = nil
            } catch {
                guard self.isCurrentProgress(generation) else { return }
                self.progressFailure = .progressFailed
            }
        }
    }

    private func loadAssets(articleID: UUID, generation: Int) {
        assetTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let loadedAssets = try await self.dependencies.readingAssetRepository.readAssets(articleID: articleID)
                guard self.isCurrentLoad(generation), self.article?.id == articleID else { return }
                self.assets = loadedAssets
                self.assetFailure = nil
            } catch {
                guard self.isCurrentLoad(generation), self.article?.id == articleID else { return }
                self.assetFailure = .assetsFailed
            }
        }
    }

    private func isCurrentLoad(_ generation: Int) -> Bool { generation == loadGeneration }
    private func isCurrentProgress(_ generation: Int) -> Bool { generation == progressGeneration }
}
