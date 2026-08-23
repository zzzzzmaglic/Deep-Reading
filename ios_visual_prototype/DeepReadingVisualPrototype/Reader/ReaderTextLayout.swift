import Foundation
import UIKit

enum ReaderTextLayoutError: Error, Equatable {
    case emptySelection
    case unknownBlock(UUID)
    case invalidOffset
}

extension NSAttributedString.Key {
    /// Drawn by `ReaderHighlightLayoutManager` against the glyph line box.
    /// UIKit's `backgroundColor` includes paragraph leading and makes CJK
    /// highlights look vertically low when line spacing is present.
    static let readerHighlightTint = NSAttributedString.Key("ReaderHighlightTint")
}

/// The single TextKit document used for rendering, anchor conversion, and progress.
/// All stored locations deliberately use UTF-16, matching both TextKit and Postgres.
struct ReaderTextLayout {
    private let article: Article
    private let blockRanges: [UUID: NSRange]
    /// Ranges for real `ArticleBlock.content` only. `blockRanges` deliberately
    /// also includes document-only newlines so TextKit can lay out each block;
    /// these ranges are the boundary for persisted anchors and clipboard text.
    private let contentRanges: [UUID: NSRange]
    /// Presentation-only text: it is visible but must never become a native
    /// text selection, clipboard value, or persisted anchor.
    private let titleRange: NSRange?
    /// Transparent spacers, paragraph terminators, images and zero-width caret
    /// guards are non-body document elements. They may be crossed by a real
    /// selection but must never become a standalone selectable item.
    private let nonSelectableLayoutRanges: [NSRange]
    private let orderedBlockIDs: [UUID]
    private let baseText: NSAttributedString

    init(article: Article, image: UIImage?) {
        self.article = article
        var ranges: [UUID: NSRange] = [:]
        var userContentRanges: [UUID: NSRange] = [:]
        var layoutOnlyRanges: [NSRange] = []
        var orderedIDs: [UUID] = []
        let text = NSMutableAttributedString()
        var articleTitleRange: NSRange?

        if !article.title.isEmpty {
            let range = NSRange(location: text.length, length: (article.title as NSString).length + 1)
            text.append(NSAttributedString(
                string: article.title + "\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: Self.titleParagraphStyle,
                ]
            ))
            articleTitleRange = range
        }

        let blocks = article.blocks.sorted(by: { $0.position < $1.position })
        for (index, block) in blocks.enumerated() {
            if index > 0 || !article.title.isEmpty {
                layoutOnlyRanges.append(Self.appendSelectionSafeSpacer(to: text, height: 30))
            }
            let range = NSRange(location: text.length, length: 0)
            let paragraphStyle = block.isFourForcesImage
                ? Self.imageParagraphStyle
                : Self.bodyParagraphStyle
            if block.isFourForcesImage {
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: -2, width: 337, height: 190)
                let attachmentText = NSMutableAttributedString(attachment: attachment)
                attachmentText.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: attachmentText.length)
                )
                text.append(attachmentText)
                // A block range is its semantic content only. The newline
                // below exists purely for TextKit layout and must not become
                // a valid progress/anchor offset for this image block.
                let imageRange = NSRange(location: range.location, length: text.length - range.location)
                ranges[block.id] = imageRange
                // An image may sit between two selectable paragraphs, but is
                // not itself text and must not produce the text edit menu.
                // The range stays in the document so a body selection can
                // travel across it to the following paragraph.
                layoutOnlyRanges.append(imageRange)
                if index < blocks.count - 1 {
                    let terminatorRange = NSRange(location: text.length, length: 1)
                    text.append(NSAttributedString(
                        string: "\n",
                        attributes: [.paragraphStyle: paragraphStyle]
                    ))
                    layoutOnlyRanges.append(terminatorRange)
                }
            } else {
                // Keep the first selectable source character away from the
                // preceding 30pt spacer's ambiguous insertion boundary.
                // TextKit otherwise gives a selection that begins at the
                // paragraph's first character a backward caret affinity, so
                // its upper handle stretches through the spacer. This
                // zero-width layout guard shares the body line but is outside
                // `contentRanges`, clipboard text and persisted anchors.
                let guardRange = NSRange(location: text.length, length: 1)
                text.append(NSAttributedString(
                    string: "\u{2060}",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 20),
                        .foregroundColor: UIColor.clear,
                        .paragraphStyle: paragraphStyle,
                        .baselineOffset: Self.bodyBaselineOffset,
                    ]
                ))
                layoutOnlyRanges.append(guardRange)
                let contentRange = NSRange(location: text.length, length: (block.content as NSString).length)
                text.append(NSAttributedString(
                    string: block.content,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 20),
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: paragraphStyle,
                        // UIKit's default 20pt system baseline sits visually
                        // high inside this app's fixed 28pt reader line box.
                        // The approved positive offset moves glyphs and native
                        // selection geometry down without changing line spacing.
                        .baselineOffset: Self.bodyBaselineOffset,
                    ]
                ))
                userContentRanges[block.id] = contentRange
                ranges[block.id] = contentRange
                if index < blocks.count - 1 {
                    let terminatorRange = NSRange(location: text.length, length: 1)
                    text.append(NSAttributedString(
                        string: "\n",
                        // A paragraph terminator participates in the final
                        // visual line's TextKit metrics. Give it the exact same
                        // font and baseline as source text so paragraph-final
                        // lines cannot fall back to default UIKit metrics.
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 20),
                            .foregroundColor: UIColor.label,
                            .paragraphStyle: paragraphStyle,
                            .baselineOffset: Self.bodyBaselineOffset,
                        ]
                    ))
                    layoutOnlyRanges.append(terminatorRange)
                }
            }
            orderedIDs.append(block.id)
        }

        blockRanges = ranges
        contentRanges = userContentRanges
        titleRange = articleTitleRange
        nonSelectableLayoutRanges = layoutOnlyRanges
        orderedBlockIDs = orderedIDs
        baseText = text
    }

    var attributedText: NSAttributedString { baseText }

    func attributedText(highlighting anchors: [TextAnchor]) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: baseText)
        for anchor in anchors where anchor.articleID == article.id {
            for range in highlightRanges(for: anchor) where range.length > 0 {
                text.addAttribute(
                    .readerHighlightTint,
                    value: UIColor(red: 0.95, green: 0.77, blue: 0.18, alpha: 0.52),
                    range: range
                )
            }
        }
        return text
    }

    func range(forBlockID blockID: UUID) -> NSRange? {
        blockRanges[blockID]
    }

    /// Used only by the DEBUG UI-test hook. It still flows through the normal
    /// TextKit anchor conversion and repository mutation path.
    func firstSelectableRange() -> NSRange? {
        orderedBlockIDs.lazy
            .compactMap { contentRanges[$0] }
            .first(where: { $0.length > 0 })
    }

    func anchor(for selection: NSRange) throws -> TextAnchor {
        let segments = try sourceSelectionSegments(for: selection)
        guard let start = segments.first, let finish = segments.last else {
            throw ReaderTextLayoutError.invalidOffset
        }
        return TextAnchor(
            id: UUID(),
            assetID: UUID(),
            articleID: article.id,
            startBlockID: start.id,
            endBlockID: finish.id,
            startUTF16Offset: start.selectedRange.location - start.contentRange.location,
            endUTF16Offset: finish.selectedRange.upperBound - finish.contentRange.location,
            selectedText: segments.map { $0.text }.joined(),
            contentChecksum: article.contentChecksum
        )
    }

    /// Extracts only source text, in article order. Paragraph spacers, layout
    /// newlines, and `NSTextAttachment` U+FFFC characters never cross this
    /// boundary, while emoji and other UTF-16 content remain unchanged.
    func selectedText(for selection: NSRange) throws -> String {
        try sourceSelectionSegments(for: selection).map { $0.text }.joined()
    }

    /// Removes layout-only characters from the two native selection endpoints.
    /// Internal paragraph gaps may remain so a cross-block selection can still
    /// be represented by one UIKit range, but neither handle can anchor to a
    /// spacer, separator or image attachment.
    func normalizedSourceSelection(_ selection: NSRange) -> NSRange? {
        guard let segments = try? sourceSelectionSegments(for: selection),
              let first = segments.first,
              let last = segments.last else { return nil }
        return NSRange(
            location: first.selectedRange.location,
            length: last.selectedRange.upperBound - first.selectedRange.location
        )
    }

    /// Returns true when UIKit selected only a presentation/layout range and
    /// no real article text. This includes the title, image attachments and
    /// paragraph layout characters. A drag that reaches body text remains
    /// valid; its endpoint is then normalized to body-only source text.
    func isStandaloneLayoutSelection(_ selection: NSRange) -> Bool {
        guard selection.length > 0,
              selection.location >= 0,
              selection.upperBound <= baseText.length else { return false }
        let containsLayoutOnlyCharacter = nonSelectableLayoutRanges.contains {
            NSIntersectionRange(selection, $0).length > 0
        }
        let containsTitle = titleRange.map {
            NSIntersectionRange(selection, $0).length > 0
        } ?? false
        let containsSourceText = contentRanges.values.contains {
            NSIntersectionRange(selection, $0).length > 0
        }
        return (containsLayoutOnlyCharacter || containsTitle) && !containsSourceText
    }

    func position(forVisibleUTF16Location location: Int) -> ReaderPosition {
        guard let endpoint = endpoint(at: location, preferringEnd: false) else {
            return ReaderPosition(blockID: nil, utf16Offset: 0)
        }
        return ReaderPosition(blockID: endpoint.blockID, utf16Offset: endpoint.offset)
    }

    func range(for anchor: TextAnchor) throws -> NSRange {
        guard anchor.articleID == article.id,
              let startContentRange = contentRanges[anchor.startBlockID],
              let endContentRange = contentRanges[anchor.endBlockID],
              anchor.startUTF16Offset >= 0,
              anchor.endUTF16Offset >= 0,
              anchor.startUTF16Offset <= startContentRange.length,
              anchor.endUTF16Offset <= endContentRange.length else {
            throw ReaderTextLayoutError.invalidOffset
        }
        let start = startContentRange.location + anchor.startUTF16Offset
        let end = endContentRange.location + anchor.endUTF16Offset
        guard start <= end else { throw ReaderTextLayoutError.invalidOffset }
        return NSRange(location: start, length: end - start)
    }

    func range(for position: ReaderPosition) -> NSRange? {
        guard let blockID = position.blockID, let blockRange = blockRanges[blockID] else { return nil }
        let offset = min(max(position.utf16Offset, 0), blockRange.length)
        let location = blockRange.location + offset
        return NSRange(location: location, length: min(1, baseText.length - location))
    }

    /// A persisted highlight is interactive as one asset. Its character range
    /// is intentionally not handed back to UIKit as a text selection.
    func highlightedAnchor(at utf16Location: Int, among anchors: [TextAnchor]) -> TextAnchor? {
        anchors.first { anchor in
            highlightRanges(for: anchor).contains { range in
                NSLocationInRange(utf16Location, range)
            }
        }
    }

    /// Used to reject UIKit's word/line expansion when a double-tap starts
    /// adjacent to a persisted underline but expands across it.
    func highlightedAnchor(intersecting selection: NSRange, among anchors: [TextAnchor]) -> TextAnchor? {
        anchors.first { anchor in
            highlightRanges(for: anchor).contains { range in
                NSIntersectionRange(selection, range).length > 0
            }
        }
    }

    private func endpoint(at location: Int, preferringEnd: Bool) -> (blockID: UUID, offset: Int)? {
        guard !orderedBlockIDs.isEmpty else { return nil }
        let boundedLocation = min(max(location, 0), baseText.length)
        for blockID in orderedBlockIDs {
            guard let range = blockRanges[blockID] else { continue }
            if boundedLocation >= range.location && boundedLocation <= range.upperBound {
                return (blockID, min(max(boundedLocation - range.location, 0), range.length))
            }
        }

        let following = orderedBlockIDs.compactMap { id -> (UUID, NSRange)? in
            blockRanges[id].map { (id, $0) }
        }.first { $0.1.location > boundedLocation }
        if preferringEnd, let previous = orderedBlockIDs.reversed().compactMap({ id -> (UUID, NSRange)? in
            blockRanges[id].map { (id, $0) }
        }).first(where: { $0.1.upperBound < boundedLocation }) {
            return (previous.0, previous.1.length)
        }
        if let following { return (following.0, 0) }
        guard let lastID = orderedBlockIDs.last, let lastRange = blockRanges[lastID] else { return nil }
        return (lastID, lastRange.length)
    }

    private func highlightRanges(for anchor: TextAnchor) -> [NSRange] {
        guard anchor.articleID == article.id,
              let startIndex = orderedBlockIDs.firstIndex(of: anchor.startBlockID),
              let endIndex = orderedBlockIDs.firstIndex(of: anchor.endBlockID),
              startIndex <= endIndex else { return [] }

        return orderedBlockIDs[startIndex...endIndex].compactMap { blockID in
            guard let contentRange = contentRanges[blockID] else { return nil }
            let lower = blockID == anchor.startBlockID ? anchor.startUTF16Offset : 0
            let upper = blockID == anchor.endBlockID ? anchor.endUTF16Offset : contentRange.length
            guard lower >= 0, upper >= lower, upper <= contentRange.length else { return nil }
            return NSRange(location: contentRange.location + lower, length: upper - lower)
        }
    }

    private func sourceSelectionSegments(for selection: NSRange) throws -> [
        (id: UUID, contentRange: NSRange, selectedRange: NSRange, text: String)
    ] {
        guard selection.location >= 0,
              selection.length > 0,
              selection.upperBound <= baseText.length else {
            throw ReaderTextLayoutError.emptySelection
        }
        let segments = orderedBlockIDs.compactMap { blockID -> (
            id: UUID,
            contentRange: NSRange,
            selectedRange: NSRange,
            text: String
        )? in
            guard let contentRange = contentRanges[blockID] else { return nil }
            let selectedRange = NSIntersectionRange(selection, contentRange)
            guard selectedRange.length > 0 else { return nil }
            return (
                blockID,
                contentRange,
                selectedRange,
                (baseText.string as NSString).substring(with: selectedRange)
            )
        }
        guard !segments.isEmpty else {
            throw ReaderTextLayoutError.invalidOffset
        }
        return segments
    }

    private static let bodyParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        // A fixed line box prevents TextKit from varying baseline distance for
        // mixed CJK, Latin and punctuation glyph runs. 28pt keeps the approved
        // 20pt body type with the requested additional breathing room.
        style.minimumLineHeight = 28
        style.maximumLineHeight = 28
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        return style
    }()

    private static let bodyBaselineOffset: CGFloat = 2

    private static let titleParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.paragraphSpacing = 0
        return style
    }()

    /// Image attachments must keep their intrinsic line-fragment height. If
    /// they inherit the fixed 28pt body line box, TextKit draws the 190pt image
    /// upward over preceding body lines.
    private static let imageParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        return style
    }()

    /// Paragraph spacing participates in UITextView's caret geometry. A
    /// separate transparent attachment line preserves the visual gap without
    /// allowing either selection handle to stretch into it.
    private static func appendSelectionSafeSpacer(
        to text: NSMutableAttributedString,
        height: CGFloat
    ) -> NSRange {
        let start = text.length
        let attachment = NSTextAttachment()
        attachment.image = UIImage()
        attachment.bounds = CGRect(x: 0, y: 0, width: 1, height: height)

        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = height
        style.maximumLineHeight = height
        style.lineSpacing = 0
        style.paragraphSpacing = 0

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 1),
            .foregroundColor: UIColor.clear,
            .paragraphStyle: style,
        ]
        let spacer = NSMutableAttributedString(attachment: attachment)
        spacer.addAttributes(attributes, range: NSRange(location: 0, length: spacer.length))
        spacer.append(NSAttributedString(string: "\n", attributes: attributes))
        text.append(spacer)
        return NSRange(location: start, length: text.length - start)
    }
}

private extension ArticleBlock {
    var isFourForcesImage: Bool {
        kind == .image || content == "[[image:four-forces]]"
    }
}
