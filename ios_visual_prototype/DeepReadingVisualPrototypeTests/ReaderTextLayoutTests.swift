import XCTest
import UIKit
@testable import DeepReadingVisualPrototype

final class ReaderTextLayoutTests: XCTestCase {
    private let articleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let firstBlockID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    private let imageBlockID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    private let secondBlockID = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!

    private var layout: ReaderTextLayout {
        ReaderTextLayout(article: article, image: UIImage())
    }

    private var paragraphLayout: ReaderTextLayout {
        ReaderTextLayout(article: Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [
                ArticleBlock(id: firstBlockID, articleID: articleID, position: 0, content: "甲😀乙", kind: .paragraph),
                ArticleBlock(id: secondBlockID, articleID: articleID, position: 1, content: "丙丁戊己", kind: .paragraph),
            ]
        ), image: nil)
    }

    func testSelectionAcrossParagraphsMapsToLocalUTF16Endpoints() throws {
        let firstRange = try XCTUnwrap(paragraphLayout.range(forBlockID: firstBlockID))
        let firstStart = firstRange.location
        let firstRemaining = firstRange.length - 2

        let anchor = try paragraphLayout.anchor(
            // Include the two UTF-16 paragraph-separator units plus four units in block two.
            for: NSRange(location: firstStart + 2, length: firstRemaining + 6)
        )

        XCTAssertEqual(anchor.startBlockID, firstBlockID)
        XCTAssertEqual(anchor.startUTF16Offset, 2)
        XCTAssertEqual(anchor.endBlockID, secondBlockID)
        XCTAssertEqual(anchor.endUTF16Offset, 4)
    }

    func testImageAttachmentAndSeparatorsPreserveTheFollowingBlockOffsets() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let imageRange = try XCTUnwrap(layout.range(forBlockID: imageBlockID))
        let secondRange = try XCTUnwrap(layout.range(forBlockID: secondBlockID))

        XCTAssertEqual(imageRange.length, 1)
        XCTAssertGreaterThan(imageRange.location, firstRange.upperBound)
        XCTAssertGreaterThan(secondRange.location, imageRange.upperBound)
        XCTAssertEqual(layout.position(forVisibleUTF16Location: secondRange.location + 1), ReaderPosition(blockID: secondBlockID, utf16Offset: 1))
    }

    func testRangeForAnchorIncludesTheParagraphBoundaryBetweenBlocks() throws {
        let anchor = TextAnchor(
            id: UUID(), assetID: UUID(), articleID: articleID,
            startBlockID: firstBlockID, endBlockID: secondBlockID,
            startUTF16Offset: 1, endUTF16Offset: 2,
            selectedText: "", contentChecksum: "checksum"
        )

        let range = try layout.range(for: anchor)
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let secondRange = try XCTUnwrap(layout.range(forBlockID: secondBlockID))
        XCTAssertEqual(range.location, firstRange.location + 1)
        XCTAssertEqual(range.upperBound, secondRange.location + 2)
    }

    func testHighlightAttributesSplitAtParagraphBoundaries() throws {
        let anchor = TextAnchor(
            id: UUID(), assetID: UUID(), articleID: articleID,
            startBlockID: firstBlockID, endBlockID: secondBlockID,
            startUTF16Offset: 1, endUTF16Offset: 2,
            selectedText: "", contentChecksum: "checksum"
        )
        let text = layout.attributedText(highlighting: [anchor])
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let secondRange = try XCTUnwrap(layout.range(forBlockID: secondBlockID))

        XCTAssertNotNil(text.attribute(.backgroundColor, at: firstRange.location + 1, effectiveRange: nil))
        XCTAssertNil(text.attribute(.backgroundColor, at: firstRange.upperBound, effectiveRange: nil))
        XCTAssertNotNil(text.attribute(.backgroundColor, at: secondRange.location + 1, effectiveRange: nil))
    }

    func testAnchorRejectsTitleSeparatorAndAttachmentOnlySelections() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let imageRange = try XCTUnwrap(layout.range(forBlockID: imageBlockID))

        XCTAssertThrowsError(try layout.anchor(for: NSRange(location: 0, length: firstRange.location)))
        XCTAssertThrowsError(try layout.anchor(for: NSRange(location: firstRange.upperBound, length: 2)))
        XCTAssertThrowsError(try layout.anchor(for: imageRange))
    }

    private var article: Article {
        Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [
                ArticleBlock(id: firstBlockID, articleID: articleID, position: 0, content: "甲😀乙", kind: .paragraph),
                ArticleBlock(id: imageBlockID, articleID: articleID, position: 1, content: "FourForces", kind: .image),
                ArticleBlock(id: secondBlockID, articleID: articleID, position: 2, content: "丙丁戊己", kind: .paragraph),
            ]
        )
    }
}
