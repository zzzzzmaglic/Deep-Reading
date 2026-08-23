import SwiftUI

struct ReadingAssetListRowSpecification: Equatable {
    let cardHeight: CGFloat
    let primaryTextSize: CGFloat
    let primaryTextLineLimit: Int
    let noteTextLineLimit: Int?
    let iconVerticalOffset: CGFloat
}

struct ReadingAssetListRowContentLayout: Equatable {
    let contentLeadingInset: CGFloat
    let quoteTopOffset: CGFloat
    let noteTopOffset: CGFloat
    let accentTopOffset: CGFloat

    init(contentLeadingInset: CGFloat, quoteTopOffset: CGFloat, noteTopOffset: CGFloat, accentTopOffset: CGFloat) {
        self.contentLeadingInset = contentLeadingInset
        self.quoteTopOffset = quoteTopOffset
        self.noteTopOffset = noteTopOffset
        self.accentTopOffset = accentTopOffset
    }

    init(contentLeadingInset: CGFloat, contentTopOffset: CGFloat, accentTopOffset: CGFloat) {
        self.init(
            contentLeadingInset: contentLeadingInset,
            quoteTopOffset: contentTopOffset,
            noteTopOffset: contentTopOffset,
            accentTopOffset: accentTopOffset
        )
    }

    var contentTopOffset: CGFloat { quoteTopOffset }
}

enum ReadingAssetListRowLayout {
    static let actionHeight: CGFloat = 44
    static let twoLineNoteHeight: CGFloat = 34
    static let linkedNoteVisibleHeight: CGFloat = 128
    static let linkedNoteContentLayout = ReadingAssetListRowContentLayout(
        contentLeadingInset: 21,
        quoteTopOffset: 34,
        noteTopOffset: 94,
        accentTopOffset: 34
    )
    static let standaloneNoteContentLayout = ReadingAssetListRowContentLayout(
        contentLeadingInset: 21,
        contentTopOffset: 37,
        accentTopOffset: 37
    )

    static func specification(for kind: ReadingAssetKind) -> ReadingAssetListRowSpecification {
        switch kind {
        case .highlight:
            ReadingAssetListRowSpecification(cardHeight: 169, primaryTextSize: 14, primaryTextLineLimit: 3, noteTextLineLimit: nil, iconVerticalOffset: -2)
        case .linkedNote:
            ReadingAssetListRowSpecification(cardHeight: 169, primaryTextSize: 14, primaryTextLineLimit: 3, noteTextLineLimit: 2, iconVerticalOffset: -2)
        case .standaloneNote:
            ReadingAssetListRowSpecification(cardHeight: 169, primaryTextSize: 14, primaryTextLineLimit: 6, noteTextLineLimit: nil, iconVerticalOffset: -2)
        }
    }
}

struct ReadingAssetListRow: View {
    let asset: ReadingAsset
    let isSelected: Bool
    let open: () -> Void
    let showInArticle: (() -> Void)?
    let accessibilityPrefix: String
    let sourceAccessibilityPrefix: String?

    init(
        asset: ReadingAsset,
        isSelected: Bool,
        open: @escaping () -> Void,
        showInArticle: (() -> Void)? = nil,
        accessibilityPrefix: String = "summary",
        sourceAccessibilityPrefix: String? = nil
    ) {
        self.asset = asset
        self.isSelected = isSelected
        self.open = open
        self.showInArticle = showInArticle
        self.accessibilityPrefix = accessibilityPrefix
        self.sourceAccessibilityPrefix = sourceAccessibilityPrefix
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: open) { primaryContent }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: primaryAreaHeight, maxHeight: primaryAreaHeight, alignment: .topLeading)
                .accessibilityIdentifier("\(accessibilityPrefix)-asset-\(asset.id.uuidString)")

            if let showInArticle {
                Button(action: showInArticle) {
                    HStack(spacing: 3) {
                        Image("SummaryLocate").resizable().scaledToFit().frame(width: 12, height: 12)
                        Text("在文中显示").font(.system(size: 11))
                    }
                    .foregroundStyle(Color(red: 0.424, green: 0.424, blue: 0.451))
                    .frame(maxWidth: .infinity, minHeight: ReadingAssetListRowLayout.actionHeight, maxHeight: ReadingAssetListRowLayout.actionHeight, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, ReadingAssetListRowLayout.linkedNoteContentLayout.contentLeadingInset)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, minHeight: ReadingAssetListRowLayout.actionHeight, maxHeight: ReadingAssetListRowLayout.actionHeight, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .bottomLeading)
                .accessibilityIdentifier(sourceAccessibilityIdentifier)
            }
        }
        .frame(maxWidth: .infinity, minHeight: specification.cardHeight, maxHeight: specification.cardHeight, alignment: .leading)
        .background(isSelected ? Color(uiColor: .systemGray5) : Color(uiColor: .systemBackground))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.925, green: 0.922, blue: 0.906), lineWidth: 1) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var primaryText: String { asset.anchor?.selectedText ?? asset.noteContent ?? "" }
    private var sourceAccessibilityIdentifier: String {
        if let sourceAccessibilityPrefix {
            return "\(sourceAccessibilityPrefix)-source-\(asset.id.uuidString)"
        }
        return "\(accessibilityPrefix)-show-in-article-\(asset.id.uuidString)"
    }
    private var accentColor: Color { asset.anchor == nil ? Color(red: 0.478, green: 0.643, blue: 0.906) : Color(red: 0.965, green: 0.812, blue: 0.282) }
    private var primaryAreaHeight: CGFloat { asset.anchor == nil ? specification.cardHeight : ReadingAssetListRowLayout.linkedNoteVisibleHeight }
    private var specification: ReadingAssetListRowSpecification { ReadingAssetListRowLayout.specification(for: asset.kind) }

    @ViewBuilder private var primaryContent: some View {
        if asset.anchor == nil { standalonePrimaryContent } else { anchoredPrimaryContent }
    }

    private var anchoredPrimaryContent: some View {
        let layout = ReadingAssetListRowLayout.linkedNoteContentLayout
        return ZStack(alignment: .topLeading) {
            assetIcon.padding(.leading, layout.contentLeadingInset).padding(.top, 13)
            quoteText.padding(.leading, layout.contentLeadingInset).padding(.trailing, 20).padding(.top, layout.quoteTopOffset)
            if let noteLineLimit = specification.noteTextLineLimit, let note = asset.noteContent, !note.isEmpty {
                Text(note)
                    .font(.system(size: specification.primaryTextSize))
                    .foregroundStyle(Color(red: 0.424, green: 0.424, blue: 0.447))
                    .lineLimit(noteLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, layout.contentLeadingInset).padding(.trailing, 20).padding(.top, layout.noteTopOffset)
            }
        }
        .frame(maxWidth: .infinity, minHeight: primaryAreaHeight, maxHeight: primaryAreaHeight, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var standalonePrimaryContent: some View {
        let layout = ReadingAssetListRowLayout.standaloneNoteContentLayout
        return ZStack(alignment: .topLeading) {
            assetIcon.padding(.leading, layout.contentLeadingInset).padding(.top, 13)
            standaloneText.padding(.leading, layout.contentLeadingInset).padding(.trailing, 20).padding(.top, layout.contentTopOffset)
        }
        .frame(maxWidth: .infinity, minHeight: primaryAreaHeight, maxHeight: primaryAreaHeight, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
    }

    private var assetIcon: some View {
        Image(asset.anchor == nil ? "SummaryStandaloneNote" : "SummaryQuote")
            .resizable().scaledToFit()
            .frame(width: asset.anchor == nil ? 15 : 20, height: asset.anchor == nil ? 18 : 15)
            .offset(y: specification.iconVerticalOffset)
    }

    private var quoteText: some View {
        Text(primaryText).font(.system(size: specification.primaryTextSize))
            .foregroundStyle(Color(red: 0.114, green: 0.114, blue: 0.122))
            .lineLimit(specification.primaryTextLineLimit).frame(maxWidth: .infinity, alignment: .leading)
            .readingAssetListAccentBar(color: accentColor, leadingInset: ReadingAssetListRowLayout.linkedNoteContentLayout.contentLeadingInset)
    }

    private var standaloneText: some View {
        Text(primaryText).font(.system(size: specification.primaryTextSize))
            .foregroundStyle(Color(red: 0.114, green: 0.114, blue: 0.122))
            .lineLimit(specification.primaryTextLineLimit).frame(maxWidth: .infinity, alignment: .leading)
            .readingAssetListAccentBar(color: accentColor, leadingInset: ReadingAssetListRowLayout.standaloneNoteContentLayout.contentLeadingInset)
    }
}

private extension View {
    func readingAssetListAccentBar(color: Color, leadingInset: CGFloat) -> some View {
        background(alignment: .topLeading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: proxy.size.height).offset(x: -leadingInset)
            }
            .allowsHitTesting(false)
        }
    }
}
