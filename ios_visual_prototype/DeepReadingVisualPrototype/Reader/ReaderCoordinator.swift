import Combine
import Foundation

struct ReaderDependencies: @unchecked Sendable {
    let articleRepository: any ArticleRepository
    let readingAssetRepository: any ReadingAssetRepository
}

struct ReaderChromeState: Equatable {
    let isVisible: Bool
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

enum ReaderSelectionFailure: LocalizedError, Equatable {
    case highlightCreationFailed
    case invalidSelection

    var errorDescription: String? {
        switch self {
        case .highlightCreationFailed: "划线未创建，请重试。"
        case .invalidSelection: "请选择正文后再划线。"
        }
    }
}

@MainActor
final class ReaderCoordinator: ObservableObject {
    enum ScrollDirection { case up, down }

    @Published private(set) var article: Article?
    @Published private(set) var assets: [ReadingAsset] = []
    @Published private(set) var presentedAssetDraft: AssetDraft?
    @Published private(set) var assetCardChromeState: ReaderChromeState?
    @Published private(set) var assetCardToken: Int?
    @Published private(set) var assetCardPresentsTags = false
    @Published private(set) var initialPosition: ReaderPosition?
    /// Increments whenever a restored progress or summary anchor is published.
    /// It survives `consumeInitialPosition()` so the UIKit viewport can apply
    /// the command once even when SwiftUI coalesces adjacent state updates.
    @Published private(set) var scrollRequestRevision = 0
    @Published private(set) var chromeIsVisible = true
    @Published private(set) var loadFailure: ReaderCoordinatorFailure?
    @Published private(set) var progressFailure: ReaderCoordinatorFailure?
    @Published private(set) var assetFailure: ReaderCoordinatorFailure?
    @Published private(set) var selectionFailure: ReaderSelectionFailure?
    /// This remains true for normal launches. The DEBUG-only UI test seeding
    /// path temporarily disables the summary entry until its real RPC result
    /// is available to read, avoiding a test-only race with an empty summary.
    @Published private(set) var uiTestHighlightSeedIsReady = true

    private let dependencies: ReaderDependencies
    private let progressDebounce: Duration
    private var layout: ReaderTextLayout?
    private var lastRoute: ReaderRoute?
    private var lastQueuedPosition: ReaderPosition?
    private var progressTask: Task<Void, Never>?
    private var assetTask: Task<Void, Never>?
    private var pendingHighlightCreation: (articleID: UUID, anchor: TextAnchor, generation: Int)?
    private var highlightRetryIsInFlight = false
    private var routeLoadIsInFlight = false
    private var loadGeneration = 0
    private var progressGeneration = 0
    private var nextAssetCardToken = 0

    init(
        dependencies: ReaderDependencies,
        progressDebounce: Duration = .milliseconds(350)
    ) {
        self.dependencies = dependencies
        self.progressDebounce = progressDebounce
        #if DEBUG
        // UI automation cannot drive a native multi-handle selection. Mark
        // the summary route unavailable before the reader first renders, so
        // the test cannot open an empty summary during the seed RPC race.
        uiTestHighlightSeedIsReady = !ProcessInfo.processInfo.arguments
            .contains("-ui-test-seed-highlight")
        #endif
    }

    deinit {
        progressTask?.cancel()
        assetTask?.cancel()
    }

    func load(route: ReaderRoute) async throws {
        let isNewRoute = lastRoute != route
        loadGeneration += 1
        let generation = loadGeneration
        progressGeneration += 1
        progressTask?.cancel()
        assetTask?.cancel()
        loadFailure = nil
        assetFailure = nil
        selectionFailure = nil
        pendingHighlightCreation = nil
        highlightRetryIsInFlight = false
        routeLoadIsInFlight = true
        if isNewRoute {
            // A draft is scoped to its source route. Stage D only prepares it,
            // so it must never be carried into a newly requested article.
            invalidateAssetCardPresentation()
            article = nil
            layout = nil
            assets = []
            initialPosition = nil
        }
        lastRoute = route
        do {
            let article = try await dependencies.articleRepository.readArticle(id: route.articleID)
            guard isCurrentLoad(generation) else { return }
            self.article = article
            layout = ReaderTextLayout(article: article, image: nil)
            routeLoadIsInFlight = false

            let persistedProgress = try await dependencies.articleRepository.readProgress(articleID: route.articleID)
            guard isCurrentLoad(generation) else { return }

            guard let anchorID = route.anchorID else {
                // A normal reader route renders restored progress before assets finish.
                publishInitialPosition(persistedProgress)
                loadAssets(articleID: route.articleID, generation: generation)
                return
            }

            do {
                let assets = try await dependencies.readingAssetRepository.readAssets(articleID: route.articleID)
                guard isCurrentLoad(generation) else { return }
                self.assets = assets
                if let anchor = assets.first(where: { $0.anchor?.id == anchorID })?.anchor {
                    publishInitialPosition(ReaderPosition(
                        blockID: anchor.startBlockID,
                        utf16Offset: anchor.startUTF16Offset
                    ))
                } else {
                    publishInitialPosition(persistedProgress)
                }
            } catch {
                guard isCurrentLoad(generation) else { return }
                assetFailure = .assetsFailed
                publishInitialPosition(persistedProgress)
            }
        } catch {
            guard isCurrentLoad(generation) else { return }
            routeLoadIsInFlight = false
            loadFailure = .loadFailed
            throw error
        }
    }

    func handleScroll(direction: ScrollDirection) {
        switch direction {
        case .down:
            hideChrome()
        case .up:
            showChrome()
        }
    }

    func handleBodyTap() {
        if chromeIsVisible {
            hideChrome()
        } else {
            showChrome()
        }
    }

    /// Converts the TextKit selection once at the domain boundary. Highlight
    /// creation is the only selection action that persists a ReadingAsset.
    func performSelection(
        _ selection: NSRange,
        action: ReaderSelectionAction
    ) async throws {
        // A new route deliberately clears the old TextKit document before its
        // read completes. An edit-menu action retained from that old view is
        // stale, so it is a no-op rather than an error shown on the new route.
        guard !routeLoadIsInFlight else { return }
        guard let article, let layout else {
            throw ReaderSelectionError.articleUnavailable
        }
        let generation = loadGeneration
        guard isCurrentSelection(articleID: article.id, generation: generation) else { return }
        let anchor = try layout.anchor(for: selection)

        switch action {
        case .highlight:
            try await createHighlight(articleID: article.id, anchor: anchor, generation: generation)
        case .openAssetCard:
            guard isCurrentSelection(articleID: article.id, generation: generation) else { return }
            if let existingAsset = assets.first(where: { existingAsset in
                guard let existingAnchor = existingAsset.anchor else { return false }
                return existingAnchor.startBlockID == anchor.startBlockID
                    && existingAnchor.endBlockID == anchor.endBlockID
                    && existingAnchor.startUTF16Offset == anchor.startUTF16Offset
                    && existingAnchor.endUTF16Offset == anchor.endUTF16Offset
            }) {
                presentAssetDraft(AssetDraft(
                    asset: existingAsset,
                    noteContent: existingAsset.noteContent,
                    selectedTagIDs: Set(existingAsset.tags.map(\.id))
                ))
            } else {
                presentAssetDraft(AssetDraft(anchor: anchor, articleID: article.id))
            }
        case .copy, .explainWithAI, .removeHighlight, .manageTags:
            // Clipboard handling belongs to UITextView. AI is deliberately a
            // no-op until the later companion workflow is implemented.
            break
        }
    }

    /// Persisted highlights are opened by a single tap, not by creating a
    /// second UIKit text selection. Their menu therefore works directly with
    /// the already-loaded ReadingAsset and its stable anchor identity.
    func performHighlightedTextAction(
        _ anchor: TextAnchor,
        action: ReaderSelectionAction
    ) async {
        guard !routeLoadIsInFlight,
              let article,
              isCurrentSelection(articleID: article.id, generation: loadGeneration),
              let asset = asset(matching: anchor) else { return }

        switch action {
        case .removeHighlight:
            do {
                try await dependencies.readingAssetRepository.deleteReadingAsset(id: asset.id)
                guard isCurrentSelection(articleID: article.id, generation: loadGeneration) else { return }
                assets.removeAll { $0.id == asset.id }
                await refreshAssets()
            } catch {
                assetFailure = .assetsFailed
            }
        case .openAssetCard:
            presentAssetDraft(draft(for: asset))
        case .manageTags:
            presentAssetDraft(draft(for: asset), presentingTags: true)
        case .copy, .explainWithAI:
            // Copy is applied by the UIKit menu. AI remains intentionally
            // inert until the companion workflow is implemented.
            break
        case .highlight:
            // A persisted highlight never re-enters the selection/create path.
            break
        }
    }

    /// Stage D prepares the draft only. Stage E owns the editor/card UI and
    /// persists the standalone note when its save path is invoked.
    @discardableResult
    func beginStandaloneNote() -> AssetDraft? {
        guard !routeLoadIsInFlight,
              let article,
              isCurrentSelection(articleID: article.id, generation: loadGeneration) else {
            return nil
        }
        let draft = AssetDraft(anchor: nil, articleID: article.id)
        presentAssetDraft(draft)
        return draft
    }

    func dismissAssetCard(token: Int, restoring chromeState: ReaderChromeState) {
        guard token == assetCardToken else { return }
        invalidateAssetCardPresentation()
        chromeIsVisible = chromeState.isVisible
    }

    func completeAssetCardSave(token: Int, restoring chromeState: ReaderChromeState) {
        guard token == assetCardToken else { return }
        dismissAssetCard(token: token, restoring: chromeState)
        Task { @MainActor [weak self] in
            await self?.refreshAssets()
        }
    }

    func completeAssetCardDelete(
        _ assetID: UUID,
        token: Int,
        restoring chromeState: ReaderChromeState
    ) {
        guard token == assetCardToken else { return }
        // The remote mutation has already succeeded at this point. Remove the
        // highlight promptly, close only now, then reconcile with the read
        // model so a failed refresh remains retryable rather than reopening.
        assets.removeAll { $0.id == assetID }
        dismissAssetCard(token: token, restoring: chromeState)
        Task { @MainActor [weak self] in
            await self?.refreshAssets()
        }
    }

    func completeAssetCardTagUpdate(token: Int) {
        guard token == assetCardToken else { return }
        Task { @MainActor [weak self] in
            await self?.refreshAssets()
        }
    }

    /// Restored progress is an initial navigation command, not persistent view
    /// state. Once TextKit has applied it, keeping it would let a later SwiftUI
    /// view recreation scroll the reader back underneath an active gesture.
    func consumeInitialPosition() {
        initialPosition = nil
    }

    private func publishInitialPosition(_ position: ReaderPosition?) {
        initialPosition = position
        guard position != nil else { return }
        scrollRequestRevision += 1
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
        chromeIsVisible = true
    }

    func hideChrome() {
        chromeIsVisible = false
    }

    private func presentAssetDraft(_ draft: AssetDraft, presentingTags: Bool = false) {
        nextAssetCardToken += 1
        assetCardToken = nextAssetCardToken
        assetCardChromeState = ReaderChromeState(isVisible: chromeIsVisible)
        assetCardPresentsTags = presentingTags
        presentedAssetDraft = draft
    }

    private func invalidateAssetCardPresentation() {
        nextAssetCardToken += 1
        assetCardToken = nil
        presentedAssetDraft = nil
        assetCardChromeState = nil
        assetCardPresentsTags = false
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

    #if DEBUG
    /// UI automation cannot reliably drive a native multi-handle TextKit
    /// selection. This creates one real, owner-scoped highlight through the
    /// production repository; it is enabled solely by an explicit launch arg.
    func seedHighlightForUITestIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-ui-test-seed-highlight") else { return }
        guard let article,
              let layout,
              let sourceRange = layout.firstSelectableRange(),
              !routeLoadIsInFlight else {
            uiTestHighlightSeedIsReady = true
            return
        }

        uiTestHighlightSeedIsReady = false
        let selection = NSRange(location: sourceRange.location, length: min(sourceRange.length, 12))
        await refreshAssets()
        guard let anchor = try? layout.anchor(for: selection) else { return }
        if assets.contains(where: {
                  $0.anchor?.startBlockID == anchor.startBlockID
                      && $0.anchor?.startUTF16Offset == anchor.startUTF16Offset
              }) {
            uiTestHighlightSeedIsReady = true
            return
        }
        do {
            try await createHighlight(articleID: article.id, anchor: anchor, generation: loadGeneration)
            uiTestHighlightSeedIsReady = true
        } catch {
            // `createHighlight` publishes its normal retryable failure state.
            uiTestHighlightSeedIsReady = true
        }
    }
    #endif

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

    /// Retries only a creation that did not report success. Once the RPC has
    /// succeeded, `pendingHighlightCreation` is cleared before refreshing so a
    /// refresh failure can never create the same highlight twice.
    func retryHighlightCreation() {
        guard let pending = pendingHighlightCreation,
              !highlightRetryIsInFlight,
              isCurrentSelection(articleID: pending.articleID, generation: pending.generation) else { return }
        // Set this before scheduling the task: SwiftUI can deliver two taps
        // before either Task first reaches the repository call.
        highlightRetryIsInFlight = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.isCurrentLoad(pending.generation) {
                    self.highlightRetryIsInFlight = false
                }
            }
            guard self.isCurrentSelection(articleID: pending.articleID, generation: pending.generation) else {
                return
            }
            do {
                try await self.createHighlight(
                    articleID: pending.articleID,
                    anchor: pending.anchor,
                    generation: pending.generation
                )
            } catch {
                // `createHighlight` has already published a retryable state.
            }
        }
    }

    /// Makes an unexpected TextKit conversion failure visible instead of
    /// allowing the view task to swallow it. Invalid selection cannot be
    /// replayed because UIKit owns the original selection handles.
    func recordSelectionFailure(for action: ReaderSelectionAction) {
        guard action == .highlight, selectionFailure == nil else { return }
        selectionFailure = .invalidSelection
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

    private func createHighlight(
        articleID: UUID,
        anchor: TextAnchor,
        generation: Int
    ) async throws {
        guard isCurrentSelection(articleID: articleID, generation: generation) else { return }
        do {
            _ = try await dependencies.readingAssetRepository.createHighlight(
                articleID: articleID,
                anchor: anchor,
                checksum: anchor.contentChecksum
            )
            // A request may finish after a route replacement. Its remote write
            // cannot be undone here, but it must never repopulate the new
            // reader or publish an error against it.
            guard isCurrentSelection(articleID: articleID, generation: generation) else { return }
            // The write has completed. A later `refreshAssets()` failure must
            // retain this fact and offer only refresh, never a second write.
            pendingHighlightCreation = nil
            selectionFailure = nil
            await refreshAssets()
        } catch {
            guard isCurrentSelection(articleID: articleID, generation: generation) else { return }
            pendingHighlightCreation = (articleID, anchor, generation)
            selectionFailure = .highlightCreationFailed
            throw error
        }
    }

    private func isCurrentLoad(_ generation: Int) -> Bool { generation == loadGeneration }

    private func asset(matching anchor: TextAnchor) -> ReadingAsset? {
        assets.first { asset in
            asset.id == anchor.assetID || asset.anchor?.id == anchor.id
        }
    }

    private func draft(for asset: ReadingAsset) -> AssetDraft {
        AssetDraft(
            asset: asset,
            noteContent: asset.noteContent,
            selectedTagIDs: Set(asset.tags.map(\.id))
        )
    }

    private func isCurrentSelection(articleID: UUID, generation: Int) -> Bool {
        isCurrentLoad(generation)
            && !routeLoadIsInFlight
            && article?.id == articleID
            && lastRoute?.articleID == articleID
    }
    private func isCurrentProgress(_ generation: Int) -> Bool { generation == progressGeneration }
}

enum ReaderSelectionError: Error, Equatable {
    case articleUnavailable
}
