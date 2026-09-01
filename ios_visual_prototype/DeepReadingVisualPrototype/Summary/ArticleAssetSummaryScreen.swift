import SwiftUI
import UIKit

struct ArticleAssetSummaryScreen: View {
    let articleID: UUID
    let origin: ReaderOrigin
    let dependencies: ReaderDependencies
    let showInArticle: (ReaderRoute) -> Void
    let refreshReaderAssets: () -> Void

    @StateObject private var coordinator: ArticleAssetSummaryCoordinator
    @State private var viewedAsset: ReadingAsset?
    @State private var cardToken = 0
    @State private var presentsDeleteConfirmation = false

    init(articleID: UUID, origin: ReaderOrigin, dependencies: ReaderDependencies, showInArticle: @escaping (ReaderRoute) -> Void, refreshReaderAssets: @escaping () -> Void) {
        self.articleID = articleID
        self.origin = origin
        self.dependencies = dependencies
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
        }
        .ignoresSafeArea()
        .navigationTitle("标注与笔记")
        .toolbarTitleDisplayMode(.inline)
        .readingAssetCardPresentation(item: assetCardPresentation) { presentation in
            ReadingAssetCard(
                draft: presentation.draft,
                repository: dependencies.readingAssetRepository,
                token: presentation.token,
                originalChromeState: presentation.originalChromeState,
                showsBackdrop: false,
                close: { _, _ in viewedAsset = nil },
                onSuccessfulSave: refreshAfterCardMutation,
                onSuccessfulDelete: { _ in refreshAfterCardMutation() },
                onSuccessfulTagUpdate: refreshAfterCardMutation
            )
            .id(presentation.token)
            .ignoresSafeArea()
        }
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
                .background(SummaryTopScrollEdgeRegistration())
            }
            .scrollIndicators(.hidden)
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

    private var assetCardPresentation: Binding<ReadingAssetCardPresentation?> {
        Binding(
            get: {
                guard let viewedAsset else { return nil }
                return ReadingAssetCardPresentation(
                    draft: AssetDraft(
                        asset: viewedAsset,
                        noteContent: viewedAsset.noteContent,
                        selectedTagIDs: Set(viewedAsset.tags.map(\.id))
                    ),
                    token: cardToken,
                    originalChromeState: ReaderChromeState(isVisible: true),
                    initiallyPresentsTags: false
                )
            },
            set: { presentation in
                if presentation == nil { viewedAsset = nil }
            }
        )
    }

    private func refreshAfterCardMutation() {
        viewedAsset = nil
        refreshReaderAssets()
        Task { await coordinator.refreshAfterAssetMutation() }
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

/// SwiftUI does not always nominate this nested list as the navigation
/// controller's top-edge scroll view. Register the underlying UIKit scroll
/// view explicitly so the summary uses the reader's native navigation-bar
/// material and control placement.
private struct SummaryTopScrollEdgeRegistration: UIViewRepresentable {
    func makeUIView(context: Context) -> SummaryTopScrollEdgeRegistrationView {
        SummaryTopScrollEdgeRegistrationView()
    }

    func updateUIView(_ uiView: SummaryTopScrollEdgeRegistrationView, context: Context) {
        uiView.registerTopScrollViewIfNeeded()
    }
}

private final class SummaryTopScrollEdgeRegistrationView: UIView {
    private weak var scrollEdgeOwner: UIViewController?
    private weak var registeredScrollView: UIScrollView?

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            unregisterTopScrollViewIfNeeded()
        } else {
            registerTopScrollViewIfNeeded()
        }
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        registerTopScrollViewIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        registerTopScrollViewIfNeeded()
    }

    func registerTopScrollViewIfNeeded() {
        guard let scrollView = enclosingScrollView,
              let owner = owningViewController else { return }

        guard scrollEdgeOwner !== owner || registeredScrollView !== scrollView else { return }
        owner.setContentScrollView(scrollView, for: .top)
        scrollEdgeOwner = owner
        registeredScrollView = scrollView
    }

    private func unregisterTopScrollViewIfNeeded() {
        if let scrollEdgeOwner,
           scrollEdgeOwner.contentScrollView(for: .top) === registeredScrollView {
            scrollEdgeOwner.setContentScrollView(nil, for: .top)
        }
        scrollEdgeOwner = nil
        registeredScrollView = nil
    }

    private var enclosingScrollView: UIScrollView? {
        var ancestor = superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView { return scrollView }
            ancestor = current.superview
        }
        return nil
    }

    private var owningViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}
