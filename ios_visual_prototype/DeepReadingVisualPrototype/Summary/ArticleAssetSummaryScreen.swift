import SwiftUI

struct ArticleAssetSummaryScreen: View {
    let articleID: UUID
    let origin: ReaderOrigin
    let dependencies: ReaderDependencies
    let dismissToReader: () -> Void
    let showInArticle: (ReaderRoute) -> Void
    let refreshReaderAssets: () -> Void

    @StateObject private var coordinator: ArticleAssetSummaryCoordinator
    @State private var viewedAsset: ReadingAsset?
    @State private var cardToken = 0
    @State private var presentsDeleteConfirmation = false

    init(articleID: UUID, origin: ReaderOrigin, dependencies: ReaderDependencies, dismissToReader: @escaping () -> Void, showInArticle: @escaping (ReaderRoute) -> Void, refreshReaderAssets: @escaping () -> Void) {
        self.articleID = articleID
        self.origin = origin
        self.dependencies = dependencies
        self.dismissToReader = dismissToReader
        self.showInArticle = showInArticle
        self.refreshReaderAssets = refreshReaderAssets
        _coordinator = StateObject(wrappedValue: ArticleAssetSummaryCoordinator(articleID: articleID, origin: origin, articleRepository: dependencies.articleRepository, readingAssetRepository: dependencies.readingAssetRepository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            if coordinator.loadFailure != nil, coordinator.assets.isEmpty {
                ContentUnavailableView {
                    Label("无法加载标注与笔记", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("重试", action: coordinator.retryLoad).buttonStyle(.borderedProminent)
                }
            } else {
                summaryList
            }
            if let viewedAsset {
                ReadingAssetCard(
                    draft: AssetDraft(asset: viewedAsset, noteContent: viewedAsset.noteContent, selectedTagIDs: Set(viewedAsset.tags.map(\.id))),
                    repository: dependencies.readingAssetRepository,
                    token: cardToken,
                    originalChromeState: ReaderChromeState(isVisible: true),
                    close: { _, _ in self.viewedAsset = nil },
                    onSuccessfulSave: refreshAfterCardMutation,
                    onSuccessfulDelete: { _ in refreshAfterCardMutation() },
                    onSuccessfulTagUpdate: refreshAfterCardMutation
                )
                .id(cardToken)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { try? await coordinator.load() }
        .alert("删除所选阅读资产？", isPresented: $presentsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task { if await coordinator.deleteSelection() { refreshReaderAssets() } }
            }
            .accessibilityIdentifier("asset-delete-confirm")
        } message: {
            Text("删除后将永久移除所选阅读资产，且无法恢复。")
        }
    }

    private var summaryList: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(coordinator.assets) { asset in
                        ReadingAssetListRow(
                            asset: asset,
                            isSelected: coordinator.selectedAssetIDs.contains(asset.id),
                            open: { openCard(asset) },
                            showInArticle: asset.anchor == nil ? nil : { showInArticle(coordinator.showInArticle(asset)) }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 24).onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height), value.translation.width > 24 else { return }
                                coordinator.toggleSelection(asset.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 11)
                .padding(.top, 123)
                .padding(.bottom, coordinator.selectedAssetIDs.isEmpty ? 24 : 128)
            }
            .scrollIndicators(.hidden)
            summaryTopProgressiveEdge
            SummaryTopChrome(back: dismissToReader)
        }
        .overlay(alignment: .bottom) {
            if !coordinator.selectedAssetIDs.isEmpty {
                SummaryDeletionToolbar(delete: { presentsDeleteConfirmation = true }).disabled(coordinator.isDeleting)
            }
        }
        .overlay(alignment: .bottom) {
            if coordinator.deletionFailure != nil {
                Button("删除失败，点此重试") {
                    Task { if await coordinator.deleteSelection() { refreshReaderAssets() } }
                }
                .disabled(coordinator.isDeleting)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, coordinator.selectedAssetIDs.isEmpty ? 24 : 114)
                .accessibilityIdentifier("summary-delete-retry")
            }
        }
    }

    private func openCard(_ asset: ReadingAsset) {
        guard coordinator.selectedAssetIDs.isEmpty else { return }
        cardToken += 1
        viewedAsset = asset
    }

    private func refreshAfterCardMutation() {
        viewedAsset = nil
        refreshReaderAssets()
        Task { await coordinator.refreshAfterAssetMutation() }
    }

    @ViewBuilder private var summaryTopProgressiveEdge: some View {
        #if DEBUG
        ReaderTopProgressiveBlur(isVisible: true, height: 116)
        #else
        LinearGradient(colors: [Color(red: 0.973, green: 0.961, blue: 0.937).opacity(0.52), .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: 116)
            .allowsHitTesting(false)
        #endif
    }
}

private struct SummaryTopChrome: View {
    let back: () -> Void

    var body: some View {
        ZStack {
            Text("标注与笔记")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(red: 0.114, green: 0.114, blue: 0.122))
                .padding(.top, 61)
            HStack {
                GlassIconControl(symbol: "chevron.left", label: "返回", action: back)
                    .accessibilityIdentifier("summary-back-to-reader")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 52)
        }
        .frame(height: 116)
        .allowsHitTesting(true)
    }
}

private struct SummaryDeletionToolbar: View {
    let delete: () -> Void

    var body: some View {
        ZStack {
            ReaderBottomSoftEdge(isVisible: true)
            Button(role: .destructive, action: delete) {
                Label("删除", systemImage: "trash").font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(.red)
        }
        .frame(height: 116)
    }
}
