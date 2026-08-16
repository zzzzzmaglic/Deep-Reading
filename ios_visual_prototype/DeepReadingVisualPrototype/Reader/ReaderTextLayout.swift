import Foundation
import UIKit

enum ReaderTextLayoutError: Error, Equatable {
    case emptySelection
    case unknownBlock(UUID)
    case invalidOffset
}

/// The single TextKit document used for rendering, anchor conversion, and progress.
/// All stored locations deliberately use UTF-16, matching both TextKit and Postgres.
struct ReaderTextLayout {
    private let article: Article
    private let blockRanges: [UUID: NSRange]
    private let orderedBlockIDs: [UUID]
    private let imageBlockIDs: Set<UUID>
    private let baseText: NSAttributedString

    init(article: Article, image: UIImage?) {
        self.article = article
        var ranges: [UUID: NSRange] = [:]
        var orderedIDs: [UUID] = []
        var imageIDs: Set<UUID> = []
        let text = NSMutableAttributedString()

        if !article.title.isEmpty {
            text.append(NSAttributedString(
                string: article.title + "\n\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                    .foregroundColor: UIColor.label,
                ]
            ))
        }

        for (index, block) in article.blocks.sorted(by: { $0.position < $1.position }).enumerated() {
            if index > 0 {
                // Separators live in the document even though they belong to no block.
                text.append(NSAttributedString(string: "\n\n"))
            }

            let range = NSRange(location: text.length, length: 0)
            if block.isFourForcesImage {
                imageIDs.insert(block.id)
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: -2, width: 337, height: 190)
                text.append(NSAttributedString(attachment: attachment))
            } else {
                text.append(NSAttributedString(
                    string: block.content,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 21),
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: Self.bodyParagraphStyle,
                    ]
                ))
            }
            ranges[block.id] = NSRange(location: range.location, length: text.length - range.location)
            orderedIDs.append(block.id)
        }

        blockRanges = ranges
        orderedBlockIDs = orderedIDs
        imageBlockIDs = imageIDs
        baseText = text
    }

    var attributedText: NSAttributedString { baseText }

    func attributedText(highlighting anchors: [TextAnchor]) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: baseText)
        for anchor in anchors where anchor.articleID == article.id {
            for range in highlightRanges(for: anchor) where range.length > 0 {
                text.addAttribute(
                    .backgroundColor,
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

    func anchor(for selection: NSRange) throws -> TextAnchor {
        guard selection.location >= 0,
              selection.length > 0,
              selection.upperBound <= baseText.length else {
            throw ReaderTextLayoutError.emptySelection
        }
        let end = selection.upperBound
        guard let start = endpoint(at: selection.location, preferringEnd: false),
              let finish = endpoint(at: end, preferringEnd: true) else {
            throw ReaderTextLayoutError.invalidOffset
        }

        let selected = (baseText.string as NSString).substring(with: selection)
        return TextAnchor(
            id: UUID(),
            assetID: UUID(),
            articleID: article.id,
            startBlockID: start.blockID,
            endBlockID: finish.blockID,
            startUTF16Offset: start.offset,
            endUTF16Offset: finish.offset,
            selectedText: selected,
            contentChecksum: article.contentChecksum
        )
    }

    func position(forVisibleUTF16Location location: Int) -> ReaderPosition {
        guard let endpoint = endpoint(at: location, preferringEnd: false) else {
            return ReaderPosition(blockID: nil, utf16Offset: 0)
        }
        return ReaderPosition(blockID: endpoint.blockID, utf16Offset: endpoint.offset)
    }

    func range(for anchor: TextAnchor) throws -> NSRange {
        guard anchor.articleID == article.id,
              let startRange = blockRanges[anchor.startBlockID],
              let endRange = blockRanges[anchor.endBlockID],
              anchor.startUTF16Offset >= 0,
              anchor.endUTF16Offset >= 0,
              anchor.startUTF16Offset <= startRange.length,
              anchor.endUTF16Offset <= endRange.length else {
            throw ReaderTextLayoutError.invalidOffset
        }
        let start = startRange.location + anchor.startUTF16Offset
        let end = endRange.location + anchor.endUTF16Offset
        guard start <= end else { throw ReaderTextLayoutError.invalidOffset }
        return NSRange(location: start, length: end - start)
    }

    func range(for position: ReaderPosition) -> NSRange? {
        guard let blockID = position.blockID, let blockRange = blockRanges[blockID] else { return nil }
        let offset = min(max(position.utf16Offset, 0), blockRange.length)
        let location = blockRange.location + offset
        return NSRange(location: location, length: min(1, baseText.length - location))
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
            guard !imageBlockIDs.contains(blockID), let blockRange = blockRanges[blockID] else { return nil }
            let lower = blockID == anchor.startBlockID ? anchor.startUTF16Offset : 0
            let upper = blockID == anchor.endBlockID ? anchor.endUTF16Offset : blockRange.length
            guard lower >= 0, upper >= lower, upper <= blockRange.length else { return nil }
            return NSRange(location: blockRange.location + lower, length: upper - lower)
        }
    }

    private static let bodyParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        return style
    }()
}

private extension ArticleBlock {
    var isFourForcesImage: Bool {
        kind == .image || content == "[[image:four-forces]]"
    }
}
