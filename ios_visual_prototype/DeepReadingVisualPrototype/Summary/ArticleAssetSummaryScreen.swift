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

    init(
        articleID: UUID,
        origin: ReaderOrigin,
        dependencies: ReaderDependencies,
        dismissToReader: @escaping () -> Void,
        showInArticle: @escaping (ReaderRoute) -> Void,
        refreshReaderAssets: @escaping () -> Void
    ) {
        self.articleID = articleID
        self.origin = origin
        self.dependencies = dependencies
        self.dismissToReader = dismissToReader
        self.showInArticle = showInArticle
        self.refreshReaderAssets = refreshReaderAssets
        _coordinator = StateObject(wrappedValue: ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: origin,
            articleRepository: dependencies.articleRepository,
            readingAssetRepository: dependencies.readingAssetRepository
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if coordinator.loadFailure != nil, coordinator.assets.isEmpty {
                ContentUnavailableView {
                    Label("无法加载标注与笔记", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("重试", action: coordinator.retryLoad)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                summaryList
            }

            if let viewedAsset {
                ReadingAssetCard(
                    draft: AssetDraft(
                        asset: viewedAsset,
                        noteContent: viewedAsset.noteContent,
                        selectedTagIDs: Set(viewedAsset.tags.map(\.id))
                    ),
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
        // The reader owns a custom glass return control. Hide NavigationStack's
        // system back control here so it cannot be rendered a second time.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { try? await coordinator.load() }
        .alert("删除所选阅读资产？", isPresented: $presentsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    if await coordinator.deleteSelection() {
                        refreshReaderAssets()
                    }
                }
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
                        SummaryAssetRow(
                            asset: asset,
                            isSelected: coordinator.selectedAssetIDs.contains(asset.id),
                            open: { openCard(asset) },
                            showInArticle: asset.anchor == nil ? nil : { showInArticle(coordinator.showInArticle(asset)) }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 24)
                                .onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height),
                                          value.translation.width > 24 else { return }
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

            SummaryTopChrome(back: returnToReader)
        }
        .overlay(alignment: .bottom) {
            if !coordinator.selectedAssetIDs.isEmpty {
                SummaryDeletionToolbar(delete: { presentsDeleteConfirmation = true })
                    .disabled(coordinator.isDeleting)
            }
        }
        .overlay(alignment: .bottom) {
            if coordinator.deletionFailure != nil {
                Button("删除失败，点此重试") {
                    Task {
                        if await coordinator.deleteSelection() {
                            refreshReaderAssets()
                        }
                    }
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

    private func returnToReader() {
        // `navigationPath` is the sole source of truth for this destination.
        // Do not combine an environment pop with this mutation: two competing
        // NavigationStack transitions can leave the summary visibly mounted.
        dismissToReader()
    }

    private func refreshAfterCardMutation() {
        viewedAsset = nil
        refreshReaderAssets()
        Task { await coordinator.refreshAfterAssetMutation() }
    }

    @ViewBuilder
    private var summaryTopProgressiveEdge: some View {
        #if DEBUG
        ReaderTopProgressiveBlur(isVisible: true, height: 116)
        #else
        LinearGradient(
            colors: [Color(red: 0.973, green: 0.961, blue: 0.937).opacity(0.52), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
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

struct SummaryAssetRowSpecification: Equatable {
    let cardHeight: CGFloat
    let primaryTextSize: CGFloat
    let primaryTextLineLimit: Int
    let noteTextLineLimit: Int?
    let iconVerticalOffset: CGFloat
}

struct SummaryAssetContentLayout: Equatable {
    let contentLeadingInset: CGFloat
    let quoteTopOffset: CGFloat
    let noteTopOffset: CGFloat
    let accentTopOffset: CGFloat

    init(
        contentLeadingInset: CGFloat,
        quoteTopOffset: CGFloat,
        noteTopOffset: CGFloat,
        accentTopOffset: CGFloat
    ) {
        self.contentLeadingInset = contentLeadingInset
        self.quoteTopOffset = quoteTopOffset
        self.noteTopOffset = noteTopOffset
        self.accentTopOffset = accentTopOffset
    }

    init(contentLeadingInset: CGFloat, contentTopOffset: CGFloat, accentTopOffset: CGFloat) {
        self.contentLeadingInset = contentLeadingInset
        quoteTopOffset = contentTopOffset
        noteTopOffset = contentTopOffset
        self.accentTopOffset = accentTopOffset
    }

    var contentTopOffset: CGFloat { quoteTopOffset }
}

enum SummaryAssetRowLayout {
    static let actionHeight: CGFloat = 44
    /// The linked-note area reserves exactly two 17pt note lines after the
    /// fixed three-line quote slot, while the full card remains 169pt high.
    static let twoLineNoteHeight: CGFloat = 34
    static let linkedNoteVisibleHeight: CGFloat = 128
    static let linkedNoteContentLayout = SummaryAssetContentLayout(
        contentLeadingInset: 21,
        quoteTopOffset: 34,
        noteTopOffset: 94,
        accentTopOffset: 34
    )
    static let standaloneNoteContentLayout = SummaryAssetContentLayout(
        contentLeadingInset: 21,
        contentTopOffset: 37,
        accentTopOffset: 37
    )

    static func specification(for kind: ReadingAssetKind) -> SummaryAssetRowSpecification {
        switch kind {
        case .highlight:
            SummaryAssetRowSpecification(
                cardHeight: 169,
                primaryTextSize: 14,
                primaryTextLineLimit: 3,
                noteTextLineLimit: nil,
                iconVerticalOffset: -2
            )
        case .linkedNote:
            SummaryAssetRowSpecification(
                cardHeight: 169,
                primaryTextSize: 14,
                primaryTextLineLimit: 3,
                noteTextLineLimit: 2,
                iconVerticalOffset: -2
            )
        case .standaloneNote:
            SummaryAssetRowSpecification(
                cardHeight: 169,
                primaryTextSize: 14,
                primaryTextLineLimit: 6,
                noteTextLineLimit: nil,
                iconVerticalOffset: -2
            )
        }
    }
}

private struct SummaryAssetRow: View {
    let asset: ReadingAsset
    let isSelected: Bool
    let open: () -> Void
    let showInArticle: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: open) {
                primaryContent
            }
            .buttonStyle(.plain)
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: primaryAreaHeight,
                maxHeight: primaryAreaHeight,
                alignment: .topLeading
            )
            .accessibilityIdentifier("summary-asset-\(asset.id.uuidString)")

            if let showInArticle {
                Button(action: showInArticle) {
                    HStack(spacing: 3) {
                        Image("SummaryLocate")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("在文中显示")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color(red: 0.424, green: 0.424, blue: 0.451))
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: SummaryAssetRowLayout.actionHeight,
                        maxHeight: SummaryAssetRowLayout.actionHeight,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, SummaryAssetRowLayout.linkedNoteContentLayout.contentLeadingInset)
                .padding(.trailing, 20)
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: SummaryAssetRowLayout.actionHeight,
                    maxHeight: SummaryAssetRowLayout.actionHeight,
                    alignment: .leading
                )
                .frame(maxHeight: .infinity, alignment: .bottomLeading)
                .accessibilityIdentifier("summary-show-in-article-\(asset.id.uuidString)")
            }
        }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: specification.cardHeight,
                maxHeight: specification.cardHeight,
                alignment: .leading
            )
            .background(isSelected ? Color(uiColor: .systemGray5) : Color(uiColor: .systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(red: 0.925, green: 0.922, blue: 0.906), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var primaryText: String {
        if let anchor = asset.anchor { return anchor.selectedText }
        return asset.noteContent ?? ""
    }

    private var accentColor: Color {
        asset.anchor == nil
            ? Color(red: 0.478, green: 0.643, blue: 0.906)
            : Color(red: 0.965, green: 0.812, blue: 0.282)
    }

    private var primaryAreaHeight: CGFloat {
        asset.anchor == nil
            ? specification.cardHeight
            : SummaryAssetRowLayout.linkedNoteVisibleHeight
    }

    private var specification: SummaryAssetRowSpecification {
        SummaryAssetRowLayout.specification(for: asset.kind)
    }

    @ViewBuilder
    private var primaryContent: some View {
        if asset.anchor == nil {
            standalonePrimaryContent
        } else {
            anchoredPrimaryContent
        }
    }

    private var anchoredPrimaryContent: some View {
        let layout = SummaryAssetRowLayout.linkedNoteContentLayout

        return ZStack(alignment: .topLeading) {
            assetIcon
                .padding(.leading, layout.contentLeadingInset)
                .padding(.top, 13)

            quoteText
                .padding(.leading, layout.contentLeadingInset)
                .padding(.trailing, 20)
                .padding(.top, layout.quoteTopOffset)

            if let noteLineLimit = specification.noteTextLineLimit,
               let note = asset.noteContent,
               !note.isEmpty {
                Text(note)
                    .font(.system(size: specification.primaryTextSize))
                    .foregroundStyle(Color(red: 0.424, green: 0.424, blue: 0.447))
                    .lineLimit(noteLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, layout.contentLeadingInset)
                    .padding(.trailing, 20)
                    .padding(.top, layout.noteTopOffset)
            }
        }
        .frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: primaryAreaHeight,
            maxHeight: primaryAreaHeight,
            alignment: .topLeading
        )
        .contentShape(Rectangle())
    }

    private var standalonePrimaryContent: some View {
        let layout = SummaryAssetRowLayout.standaloneNoteContentLayout

        return ZStack(alignment: .topLeading) {
            assetIcon
                .padding(.leading, layout.contentLeadingInset)
                .padding(.top, 13)

            standaloneText
                .padding(.leading, layout.contentLeadingInset)
                .padding(.trailing, 20)
                .padding(.top, layout.contentTopOffset)
        }
        .frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: primaryAreaHeight,
            maxHeight: primaryAreaHeight,
            alignment: .topLeading
        )
        .clipped()
        .contentShape(Rectangle())
    }

    private var assetIcon: some View {
        Image(asset.anchor == nil ? "SummaryStandaloneNote" : "SummaryQuote")
            .resizable()
            .scaledToFit()
            .frame(
                width: asset.anchor == nil ? 15 : 20,
                height: asset.anchor == nil ? 18 : 15
            )
            .offset(y: specification.iconVerticalOffset)
    }

    private var quoteText: some View {
        Text(primaryText)
            .font(.system(size: specification.primaryTextSize))
            .foregroundStyle(Color(red: 0.114, green: 0.114, blue: 0.122))
            .lineLimit(specification.primaryTextLineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .summaryAccentBar(color: accentColor, leadingInset: SummaryAssetRowLayout.linkedNoteContentLayout.contentLeadingInset)
    }

    private var standaloneText: some View {
        Text(primaryText)
            .font(.system(size: specification.primaryTextSize))
            .foregroundStyle(Color(red: 0.114, green: 0.114, blue: 0.122))
            .lineLimit(specification.primaryTextLineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .summaryAccentBar(color: accentColor, leadingInset: SummaryAssetRowLayout.standaloneNoteContentLayout.contentLeadingInset)
    }
}

private extension View {
    func summaryAccentBar(color: Color, leadingInset: CGFloat) -> some View {
        background(alignment: .topLeading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: proxy.size.height)
                    .offset(x: -leadingInset)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct SummaryDeletionToolbar: View {
    let delete: () -> Void

    var body: some View {
        ZStack {
            ReaderBottomSoftEdge(isVisible: true)
            Button(role: .destructive, action: delete) {
                Label("删除", systemImage: "trash")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(.red)
        }
        .frame(height: 116)
    }
}
