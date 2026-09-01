import SwiftUI
import UIKit

struct CollectionDetailScreen: View {
    @StateObject private var coordinator: CollectionDetailCoordinator
    let collectionID: UUID
    let initialTitle: String
    let selectionStateChanged: (Bool) -> Void
    let openArticle: (KnowledgeArticlePreview) -> Void
    @State private var displaysRemovalFailure = false

    init(collectionID: UUID, initialTitle: String, repository: any KnowledgeBaseRepository, selectionStateChanged: @escaping (Bool) -> Void = { _ in }, openArticle: @escaping (KnowledgeArticlePreview) -> Void = { _ in }) {
        self.collectionID = collectionID
        self.initialTitle = initialTitle
        self.selectionStateChanged = selectionStateChanged
        self.openArticle = openArticle
        _coordinator = StateObject(wrappedValue: CollectionDetailCoordinator(repository: repository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: KnowledgeDetailLayout.collectionCardSpacing) {
                    ForEach(coordinator.articles) { article in
                        articleCard(for: article)
                    }
                }
                .padding(.horizontal, KnowledgeVisualTokens.pageInset)
                .padding(.top, KnowledgeDetailLayout.collectionContentTopInset)
                .padding(.bottom, coordinator.selectedArticleIDs.isEmpty ? 128 : 160)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            if !coordinator.isLockedCollection, !coordinator.selectedArticleIDs.isEmpty {
                ZStack {
                    ReaderBottomSoftEdge(isVisible: true)
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
                }
                .frame(height: KnowledgeVisualTokens.progressiveEdgeHeight)
            }
        }
        .navigationTitle(
            KnowledgeDetailNavigationTitlePolicy.title(
                initialTitle: initialTitle,
                loadedTitle: coordinator.collection?.name
            )
        )
        .toolbarTitleDisplayMode(.inline)
        .task { await coordinator.load(collectionID: collectionID) }
        .onChange(of: coordinator.selectedArticleIDs) { _, selection in
            selectionStateChanged(!selection.isEmpty)
        }
        .onDisappear { selectionStateChanged(false) }
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

}

private struct KnowledgeArticleCard: View {
    let article: KnowledgeArticlePreview
    let selected: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 24) {
                cover
                VStack(alignment: .leading, spacing: 0) {
                    CollectionArticleTitleLabelView(title: article.title)
                        .frame(width: KnowledgeDetailLayout.collectionTitleTextWidth, height: 42, alignment: .topLeading)
                        #if DEBUG
                        .overlay {
                            Rectangle()
                                .strokeBorder(.cyan, lineWidth: 1)
                                .allowsHitTesting(false)
                                .accessibilityIdentifier("collection-article-title-container")
                                .accessibilityLabel("文章标题文本框")
                        }
                        #endif
                        .padding(.top, 5)
                    metadata
                        .padding(.top, 14)
                }
                .frame(width: KnowledgeDetailLayout.collectionTitleTextWidth, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, KnowledgeDetailLayout.collectionCardContentInset)
            .padding(.top, KnowledgeDetailLayout.collectionCardContentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(height: KnowledgeVisualTokens.cardHeight)
            .background(selected ? Color.black.opacity(0.08) : .white)
            .clipShape(RoundedRectangle(cornerRadius: KnowledgeVisualTokens.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: KnowledgeVisualTokens.cardCornerRadius)
                    .stroke(Color(hex: 0xECEBE7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var cover: some View {
        Image(article.coverAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: KnowledgeVisualTokens.coverWidth, height: KnowledgeVisualTokens.coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: KnowledgeDetailLayout.collectionCoverCornerRadius))
            .shadow(color: Color(hex: 0x595959), radius: 4, x: 3, y: 3)
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 15, height: 15)
                        .shadow(color: .black.opacity(0.68), radius: 1.5, x: 0, y: 1)
                    Text("\(article.readingAssetCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: 0x333333))
                }
                    .offset(x: 4, y: -2)
                    .accessibilityLabel("\(article.readingAssetCount) 条阅读资产")
            }
    }

    private var metadata: some View {
        HStack(spacing: 0) {
            HStack(spacing: KnowledgeDetailLayout.collectionMetadataGroupSpacing) {
                metadataGroup(symbol: "folder.circle", text: article.sourceName)
                metadataGroup(symbol: "eye.circle", text: article.cognitiveDimension)
            }
            Spacer(minLength: 0)
            Text(KnowledgeRelativeDate.displayText(for: article.publishedAt, now: Date(), calendar: .current))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: 0x6C6C72).opacity(0.54))
                .lineLimit(1)
        }
        .frame(width: KnowledgeDetailLayout.collectionTitleTextWidth, height: 15, alignment: .leading)
    }

    private func metadataGroup(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 13, height: 13)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(Color(hex: 0xB0B0B3))
    }
}

private struct CollectionArticleTitleLabelView: UIViewRepresentable {
    let title: String

    func makeUIView(context: Context) -> CollectionArticleTitleLabel {
        let label = CollectionArticleTitleLabel()
        label.configure(title: title)
        return label
    }

    func updateUIView(_ label: CollectionArticleTitleLabel, context: Context) {
        label.configure(title: title)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CollectionArticleTitleLabel, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? KnowledgeDetailLayout.collectionTitleTextWidth,
            height: proposal.height ?? 42
        )
    }
}

final class CollectionArticleTitleLabel: UIView {
    private let titleLabel = UILabel()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byCharWrapping
        titleLabel.lineBreakStrategy = []
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor(KnowledgeVisualTokens.primaryText)
        titleLabel.textAlignment = .left
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 2
        paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.lineBreakStrategy = []

        titleLabel.attributedText = NSAttributedString(
            string: title,
            attributes: [
                .font: titleLabel.font as Any,
                .foregroundColor: titleLabel.textColor as Any,
                .paragraphStyle: paragraphStyle,
            ]
        )
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let fittingSize = titleLabel.sizeThatFits(
            CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        )
        titleLabel.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: min(bounds.height, ceil(fittingSize.height))
        )
    }

}
