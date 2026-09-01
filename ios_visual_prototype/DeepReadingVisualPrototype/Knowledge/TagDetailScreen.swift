import SwiftUI

struct TagDetailSelectionConfirmation {
    let title: String
    let message: String
    let confirmTitle: String
    let confirmAccessibilityIdentifier: String
    let isDestructive: Bool

    init(action: TagSelectionAction) {
        switch action {
        case .removeAssociation:
            title = "移除所选阅读资产？"
            message = "这只会移除所选资产与当前标签的关联；资产和其他标签会保留。"
            confirmTitle = "移除"
            confirmAccessibilityIdentifier = "knowledge-confirm-remove"
            isDestructive = false
        case .deleteAssets:
            title = "删除所选阅读资产？"
            message = "删除后将永久移除所选阅读资产，且无法恢复。"
            confirmTitle = "删除"
            confirmAccessibilityIdentifier = "knowledge-confirm-delete"
            isDestructive = true
        }
    }
}

struct TagDetailScreen: View {
    let tagID: UUID
    let initialTitle: String
    let dependencies: ReaderDependencies
    let selectionStateChanged: (Bool) -> Void
    let showInArticle: (ReaderRoute) -> Void

    @StateObject private var coordinator: TagDetailCoordinator
    @State private var cardToken = 0
    @State private var presentsSelectionConfirmation = false

    init(tagID: UUID, initialTitle: String, dependencies: ReaderDependencies, selectionStateChanged: @escaping (Bool) -> Void = { _ in }, showInArticle: @escaping (ReaderRoute) -> Void = { _ in }) {
        self.tagID = tagID
        self.initialTitle = initialTitle
        self.dependencies = dependencies
        self.selectionStateChanged = selectionStateChanged
        self.showInArticle = showInArticle
        _coordinator = StateObject(wrappedValue: TagDetailCoordinator(repository: dependencies.readingAssetRepository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            assetList
            if presentsSelectionConfirmation {
                selectionConfirmation
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { selectionToolbar }
        .navigationTitle(
            KnowledgeDetailNavigationTitlePolicy.title(
                initialTitle: initialTitle,
                loadedTitle: coordinator.tag?.name
            )
        )
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: beginStandaloneNote) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("添加独立型笔记")
                .accessibilityIdentifier("knowledge-system-open-standalone-note")
            }
        }
        .readingAssetCardPresentation(item: assetCardPresentation) { presentation in
            ReadingAssetCard(
                draft: presentation.draft,
                repository: dependencies.readingAssetRepository,
                token: presentation.token,
                originalChromeState: presentation.originalChromeState,
                showsBackdrop: false,
                close: { _, _ in coordinator.dismissPresentedDraft() },
                onSuccessfulSave: refreshAfterCardMutation,
                onSuccessfulDelete: { _ in refreshAfterCardMutation() },
                onSuccessfulTagUpdate: refreshAfterCardMutation
            )
            .id(presentation.token)
            .ignoresSafeArea()
        }
        .task { await coordinator.load(tagID: tagID) }
        .onChange(of: coordinator.selectedAssetIDs) { _, selection in
            selectionStateChanged(!selection.isEmpty)
        }
        .onDisappear { selectionStateChanged(false) }
    }

    private var assetList: some View {
        ScrollView {
            LazyVStack(spacing: KnowledgeDetailLayout.tagAssetSpacing) {
                ForEach(coordinator.assets) { asset in
                    ReadingAssetListRow(
                        asset: asset,
                        isSelected: coordinator.selectedAssetIDs.contains(asset.id),
                        open: { open(asset) },
                        showInArticle: coordinator.routeToSource(for: asset).map { route in { showInArticle(route) } },
                        accessibilityPrefix: "knowledge",
                        sourceAccessibilityPrefix: "knowledge"
                    )
                    .simultaneousGesture(selectionGesture(for: asset))
                }
            }
            .padding(.horizontal, KnowledgeVisualTokens.pageInset)
            .padding(.top, KnowledgeDetailLayout.contentTopInset)
            .padding(.bottom, coordinator.selectedAssetIDs.isEmpty ? 126 : 160)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    @ViewBuilder private var selectionToolbar: some View {
        if !coordinator.selectedAssetIDs.isEmpty {
            ZStack {
                ReaderBottomSoftEdge(isVisible: true)
                Button(selectionToolbarTitle) { presentsSelectionConfirmation = true }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(coordinator.selectionAction == .deleteAssets ? .red : .primary)
                    .disabled(coordinator.isMutating)
            }
            .frame(height: KnowledgeVisualTokens.progressiveEdgeHeight)
        }
    }

    private var selectionConfirmation: some View {
        let confirmation = TagDetailSelectionConfirmation(action: coordinator.selectionAction)
        return AssetCardConfirmationDialog(
            title: confirmation.title,
            message: confirmation.message,
            primaryTitle: "取消",
            primaryAction: { presentsSelectionConfirmation = false },
            destructiveTitle: confirmation.confirmTitle,
            destructiveAction: confirmSelection,
            isOperationInFlight: coordinator.isMutating,
            destructiveAccessibilityIdentifier: confirmation.confirmAccessibilityIdentifier
        )
    }

    private var selectionToolbarTitle: String { coordinator.selectionAction == .deleteAssets ? "删除" : "移除" }

    private func selectionGesture(for asset: ReadingAsset) -> some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            guard value.translation.width > 24, abs(value.translation.width) > abs(value.translation.height) else { return }
            coordinator.toggleSelection(asset.id)
        }
    }

    private func open(_ asset: ReadingAsset) {
        guard coordinator.selectedAssetIDs.isEmpty else { return }
        cardToken += 1
        coordinator.presentAsset(asset)
    }

    private func beginStandaloneNote() {
        cardToken += 1
        coordinator.beginStandaloneNote()
    }

    private var assetCardPresentation: Binding<ReadingAssetCardPresentation?> {
        Binding(
            get: {
                guard let draft = coordinator.presentedDraft else { return nil }
                return ReadingAssetCardPresentation(
                    draft: draft,
                    token: cardToken,
                    originalChromeState: ReaderChromeState(isVisible: true),
                    initiallyPresentsTags: false
                )
            },
            set: { presentation in
                if presentation == nil { coordinator.dismissPresentedDraft() }
            }
        )
    }

    private func confirmSelection() {
        Task {
            if await coordinator.applySelectionAction() {
                presentsSelectionConfirmation = false
            }
        }
    }

    private func refreshAfterCardMutation() {
        Task { await coordinator.refreshAfterAssetMutation() }
    }
}
