import SwiftUI

struct CollectionDetailScreen: View {
    @StateObject private var coordinator: CollectionDetailCoordinator
    let collectionID: UUID
    let dismiss: () -> Void
    let openArticle: (KnowledgeArticlePreview) -> Void
    @State private var displaysRemovalFailure = false

    init(collectionID: UUID, repository: any KnowledgeBaseRepository, dismiss: @escaping () -> Void = {}, openArticle: @escaping (KnowledgeArticlePreview) -> Void = { _ in }) {
        self.collectionID = collectionID
        self.dismiss = dismiss
        self.openArticle = openArticle
        _coordinator = StateObject(wrappedValue: CollectionDetailCoordinator(repository: repository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: KnowledgeVisualTokens.cardSpacing) {
                    ForEach(coordinator.articles) { article in
                        articleCard(for: article)
                    }
                }
                .padding(.horizontal, KnowledgeVisualTokens.pageInset)
                .padding(.top, 116)
                .padding(.bottom, coordinator.selectedArticleIDs.isEmpty ? 128 : 160)
            }
            .scrollIndicators(.hidden)
            detailTopEdge
            detailTopChrome
        }
        .overlay(alignment: .bottom) {
            if !coordinator.isLockedCollection, !coordinator.selectedArticleIDs.isEmpty {
                VStack(spacing: 8) {
                    if displaysRemovalFailure { Text("移除失败，请重试。").font(.footnote.weight(.medium)) }
                    Button("移除") {
                        Task {
                            let removed = await coordinator.removeSelection()
                            displaysRemovalFailure = !removed
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(coordinator.isRemoving)
                }
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [.clear, KnowledgeVisualTokens.background], startPoint: .top, endPoint: .bottom).frame(height: KnowledgeVisualTokens.progressiveEdgeHeight))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await coordinator.load(collectionID: collectionID) }
    }

    private func selectionGesture(for article: KnowledgeArticlePreview) -> some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            guard value.translation.width > 24, abs(value.translation.width) > abs(value.translation.height) else { return }
            coordinator.toggleSelection(articleID: article.id)
        }
    }

    @ViewBuilder private func articleCard(for article: KnowledgeArticlePreview) -> some View {
        let card = KnowledgeArticleCard(article: article, selected: coordinator.selectedArticleIDs.contains(article.id)) {
            guard coordinator.selectedArticleIDs.isEmpty else { return }
            openArticle(article)
        }
        if CollectionDetailScreenPolicy.attachesSelectionGesture(isLockedCollection: coordinator.isLockedCollection) {
            card.simultaneousGesture(selectionGesture(for: article))
        } else {
            card
        }
    }

    private var detailTopChrome: some View {
        ZStack {
            Text(coordinator.collection?.name ?? "合集")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KnowledgeVisualTokens.primaryText)
                .padding(.top, 61)
            HStack {
                GlassIconControl(symbol: "chevron.left", label: "返回", action: dismiss)
                Spacer()
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
}

private struct KnowledgeArticleCard: View {
    let article: KnowledgeArticlePreview
    let selected: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 24) {
                Image(article.coverAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: KnowledgeVisualTokens.coverWidth, height: KnowledgeVisualTokens.coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(KnowledgeVisualTokens.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(article.cognitiveDimension) · \(KnowledgeRelativeDate.displayText(for: article.publishedAt, now: Date(), calendar: .current))")
                        .font(.system(size: 11))
                        .foregroundStyle(KnowledgeVisualTokens.secondaryText)
                    if article.readingAssetCount > 0 {
                        Text("\(article.readingAssetCount) 条标注与笔记")
                            .font(.system(size: 11))
                            .foregroundStyle(KnowledgeVisualTokens.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: KnowledgeVisualTokens.cardHeight)
            .background(selected ? Color.black.opacity(0.08) : .white)
            .clipShape(RoundedRectangle(cornerRadius: KnowledgeVisualTokens.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }
}
