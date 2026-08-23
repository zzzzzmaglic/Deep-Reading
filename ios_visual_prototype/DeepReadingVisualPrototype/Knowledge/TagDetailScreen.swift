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
            confirmAccessibilityIdentifier = "tag-remove-confirm"
            isDestructive = false
        case .deleteAssets:
            title = "删除所选阅读资产？"
            message = "删除后将永久移除所选阅读资产，且无法恢复。"
            confirmTitle = "删除"
            confirmAccessibilityIdentifier = "tag-delete-confirm"
            isDestructive = true
        }
    }
}

struct TagDetailScreen: View {
    let tagID: UUID
    let dependencies: ReaderDependencies
    let dismiss: () -> Void
    let showInArticle: (ReaderRoute) -> Void

    @StateObject private var coordinator: TagDetailCoordinator
    @State private var cardToken = 0
    @State private var presentsSelectionConfirmation = false

    init(tagID: UUID, dependencies: ReaderDependencies, dismiss: @escaping () -> Void = {}, showInArticle: @escaping (ReaderRoute) -> Void = { _ in }) {
        self.tagID = tagID
        self.dependencies = dependencies
        self.dismiss = dismiss
        self.showInArticle = showInArticle
        _coordinator = StateObject(wrappedValue: TagDetailCoordinator(repository: dependencies.readingAssetRepository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            assetList
            detailTopEdge
            detailTopChrome
            if let draft = coordinator.presentedDraft {
                ReadingAssetCard(
                    draft: draft, repository: dependencies.readingAssetRepository, token: cardToken,
                    originalChromeState: ReaderChromeState(isVisible: true),
                    close: { _, _ in coordinator.dismissPresentedDraft() },
                    onSuccessfulSave: refreshAfterCardMutation,
                    onSuccessfulDelete: { _ in refreshAfterCardMutation() },
                    onSuccessfulTagUpdate: refreshAfterCardMutation
                )
                .id(cardToken)
            }

            if presentsSelectionConfirmation {
                selectionConfirmation
            }
        }
        .overlay(alignment: .bottom) { selectionToolbar }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await coordinator.load(tagID: tagID) }
    }

    private var assetList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(coordinator.assets) { asset in
                    ReadingAssetListRow(
                        asset: asset,
                        isSelected: coordinator.selectedAssetIDs.contains(asset.id),
                        open: { open(asset) },
                        showInArticle: coordinator.routeToSource(for: asset).map { route in { showInArticle(route) } },
                        accessibilityPrefix: "tag"
                    )
                    .simultaneousGesture(selectionGesture(for: asset))
                }
            }
            .padding(.horizontal, KnowledgeVisualTokens.pageInset)
            .padding(.top, KnowledgeVisualTokens.progressiveEdgeHeight + 7)
            .padding(.bottom, coordinator.selectedAssetIDs.isEmpty ? 126 : 160)
        }
        .scrollIndicators(.hidden)
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

    private var detailTopChrome: some View {
        ZStack {
            Text(coordinator.tag?.name ?? "标签")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KnowledgeVisualTokens.primaryText)
                .padding(.top, 61)
            HStack {
                GlassIconControl(symbol: "chevron.left", label: "返回", action: dismiss)
                Spacer()
                GlassIconControl(symbol: "square.and.pencil", label: "添加独立型笔记", action: beginStandaloneNote)
            }
            .padding(.horizontal, 20)
            .padding(.top, 52)
        }
        .frame(height: KnowledgeVisualTokens.progressiveEdgeHeight)
    }

    @ViewBuilder private var detailTopEdge: some View {
        #if DEBUG
        ReaderTopProgressiveBlur(isVisible: true, height: KnowledgeVisualTokens.progressiveEdgeHeight)
        #else
        LinearGradient(colors: [KnowledgeVisualTokens.background.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: KnowledgeVisualTokens.progressiveEdgeHeight)
        #endif
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
