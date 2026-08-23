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
        let selectionStart = firstRange.location + 2
        let secondRange = try XCTUnwrap(paragraphLayout.range(forBlockID: secondBlockID))

        let anchor = try paragraphLayout.anchor(
            // Cross the document-only spacer and stop four UTF-16 units into
            // the second source block.
            for: NSRange(location: selectionStart, length: secondRange.location + 4 - selectionStart)
        )

        XCTAssertEqual(anchor.startBlockID, firstBlockID)
        XCTAssertEqual(anchor.startUTF16Offset, 2)
        XCTAssertEqual(anchor.endBlockID, secondBlockID)
        XCTAssertEqual(anchor.endUTF16Offset, 4)
    }

    func testCrossBlockEmojiAndImageSelectionUsesOnlySourceTextForAnchorAndCopy() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let secondRange = try XCTUnwrap(layout.range(forBlockID: secondBlockID))
        let selection = NSRange(
            location: firstRange.location + 1,
            length: secondRange.location + 2 - (firstRange.location + 1)
        )

        let anchor = try layout.anchor(for: selection)
        let copyText = try layout.selectedText(for: selection)

        XCTAssertEqual(anchor.startUTF16Offset, 1)
        XCTAssertEqual(anchor.endUTF16Offset, 2)
        XCTAssertEqual(anchor.selectedText, "😀乙丙丁")
        XCTAssertEqual(copyText, "😀乙丙丁")
        XCTAssertFalse(anchor.selectedText.contains("\n"))
        XCTAssertFalse(anchor.selectedText.contains("\u{FFFC}"))
        XCTAssertFalse(layout.isStandaloneLayoutSelection(selection))
    }

    func testTrailingLayoutSpacerAndAttachmentAreOmittedFromAnchorAndCopy() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let imageRange = try XCTUnwrap(layout.range(forBlockID: imageBlockID))
        let selection = NSRange(
            location: firstRange.location + 1,
            length: imageRange.upperBound - (firstRange.location + 1)
        )

        let anchor = try layout.anchor(for: selection)

        XCTAssertEqual(anchor.startBlockID, firstBlockID)
        XCTAssertEqual(anchor.endBlockID, firstBlockID)
        XCTAssertEqual(anchor.startUTF16Offset, 1)
        XCTAssertEqual(anchor.endUTF16Offset, 4)
        XCTAssertEqual(anchor.selectedText, "😀乙")
        XCTAssertEqual(try layout.selectedText(for: selection), "😀乙")
    }

    func testNativeSelectionEndpointsAreClampedToSourceText() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let secondRange = try XCTUnwrap(layout.range(forBlockID: secondBlockID))
        let selectionIncludingLayoutCharacters = NSRange(
            location: firstRange.upperBound,
            length: secondRange.location + 2 - firstRange.upperBound
        )

        XCTAssertEqual(
            layout.normalizedSourceSelection(selectionIncludingLayoutCharacters),
            NSRange(location: secondRange.location, length: 2)
        )
        XCTAssertFalse(layout.isStandaloneLayoutSelection(selectionIncludingLayoutCharacters))
    }

    func testParagraphGapCannotBecomeAStandaloneSelection() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let imageRange = try XCTUnwrap(layout.range(forBlockID: imageBlockID))

        XCTAssertTrue(
            layout.isStandaloneLayoutSelection(
                NSRange(location: firstRange.upperBound, length: 1)
            )
        )
        // An image is visually present but not text: a standalone image tap
        // must clear the native selection and never show text actions.
        XCTAssertTrue(layout.isStandaloneLayoutSelection(imageRange))
    }

    func testArticleTitleCannotBecomeAStandaloneSelection() throws {
        let titleRange = NSRange(location: 0, length: (article.title as NSString).length)
        let firstBodyRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))

        XCTAssertTrue(layout.isStandaloneLayoutSelection(titleRange))

        // A drag beginning in the title and ending in body text is reduced to
        // source text only, so the title never stays in the native selection.
        let mixedRange = NSRange(
            location: titleRange.location,
            length: firstBodyRange.location + 1 - titleRange.location
        )
        XCTAssertFalse(layout.isStandaloneLayoutSelection(mixedRange))
        XCTAssertEqual(
            layout.normalizedSourceSelection(mixedRange),
            NSRange(location: firstBodyRange.location, length: 1)
        )
    }

    func testTextBlockStartsAfterAZeroWidthSelectionGuard() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let secondRange = try XCTUnwrap(layout.range(forBlockID: secondBlockID))
        let document = layout.attributedText.string as NSString

        XCTAssertEqual(document.substring(with: NSRange(location: firstRange.location - 1, length: 1)), "\u{2060}")
        XCTAssertEqual(document.substring(with: NSRange(location: secondRange.location - 1, length: 1)), "\u{2060}")
        XCTAssertEqual(try layout.selectedText(for: firstRange), "甲😀乙")
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

        XCTAssertNotNil(text.attribute(.readerHighlightTint, at: firstRange.location + 1, effectiveRange: nil))
        XCTAssertNil(text.attribute(.readerHighlightTint, at: firstRange.upperBound, effectiveRange: nil))
        XCTAssertNotNil(text.attribute(.readerHighlightTint, at: secondRange.location + 1, effectiveRange: nil))
    }

    func testPersistedHighlightIsFoundByTapWithoutUsingUIKitSelection() throws {
        let anchor = TextAnchor(
            id: UUID(), assetID: UUID(), articleID: articleID,
            startBlockID: firstBlockID, endBlockID: firstBlockID,
            startUTF16Offset: 1, endUTF16Offset: 4,
            selectedText: "😀乙", contentChecksum: "checksum"
        )
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))

        XCTAssertEqual(
            layout.highlightedAnchor(at: firstRange.location + 2, among: [anchor])?.id,
            anchor.id
        )
        XCTAssertNil(layout.highlightedAnchor(at: firstRange.location, among: [anchor]))
    }

    func testEveryLineLocationInsideAMultilineHighlightResolvesTheSameAnchor() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let anchor = TextAnchor(
            id: UUID(), assetID: UUID(), articleID: articleID,
            startBlockID: firstBlockID, endBlockID: firstBlockID,
            startUTF16Offset: 0, endUTF16Offset: firstRange.length,
            selectedText: "甲😀乙", contentChecksum: "checksum"
        )

        for location in firstRange.location..<firstRange.upperBound {
            XCTAssertEqual(layout.highlightedAnchor(at: location, among: [anchor])?.id, anchor.id)
        }
    }

    func testWordSelectionCrossingAnUnderlineIsRejectedAsAnExistingHighlight() throws {
        let firstRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let anchor = TextAnchor(
            id: UUID(), assetID: UUID(), articleID: articleID,
            startBlockID: firstBlockID, endBlockID: firstBlockID,
            startUTF16Offset: 1, endUTF16Offset: 3,
            selectedText: "😀", contentChecksum: "checksum"
        )
        // Starts one source character before the underline, as UIKit can do
        // while expanding a double-tap to a word boundary.
        let expandedWord = NSRange(location: firstRange.location, length: 4)

        XCTAssertEqual(
            layout.highlightedAnchor(intersecting: expandedWord, among: [anchor])?.id,
            anchor.id
        )
    }

    func testReaderTypographyUsesTheApprovedSizesAlignmentAndSpacing() throws {
        let text = paragraphLayout.attributedText
        let titleFont = try XCTUnwrap(text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let titleStyle = try XCTUnwrap(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        let firstRange = try XCTUnwrap(paragraphLayout.range(forBlockID: firstBlockID))
        let bodyFont = try XCTUnwrap(text.attribute(.font, at: firstRange.location, effectiveRange: nil) as? UIFont)
        let bodyStyle = try XCTUnwrap(text.attribute(.paragraphStyle, at: firstRange.location, effectiveRange: nil) as? NSParagraphStyle)

        XCTAssertEqual(titleFont.pointSize, 30)
        XCTAssertEqual(titleFont.fontDescriptor.symbolicTraits.contains(.traitBold), true)
        XCTAssertEqual(bodyFont.pointSize, 20)
        XCTAssertEqual(titleStyle.alignment, .left)
        XCTAssertEqual(bodyStyle.alignment, .left)
        XCTAssertEqual(titleStyle.paragraphSpacing, 0)
        XCTAssertEqual(bodyStyle.paragraphSpacing, 0)
        XCTAssertEqual(bodyStyle.minimumLineHeight, 28)
        XCTAssertEqual(bodyStyle.maximumLineHeight, 28)
        XCTAssertEqual(bodyStyle.lineSpacing, 0)
        XCTAssertEqual(text.attribute(.baselineOffset, at: firstRange.location, effectiveRange: nil) as? CGFloat, 2)

        let paragraphTerminatorFont = try XCTUnwrap(
            text.attribute(.font, at: firstRange.upperBound, effectiveRange: nil) as? UIFont
        )
        let paragraphTerminatorStyle = try XCTUnwrap(
            text.attribute(.paragraphStyle, at: firstRange.upperBound, effectiveRange: nil) as? NSParagraphStyle
        )
        XCTAssertEqual(paragraphTerminatorFont.pointSize, bodyFont.pointSize)
        XCTAssertEqual(paragraphTerminatorStyle.minimumLineHeight, bodyStyle.minimumLineHeight)
        XCTAssertEqual(paragraphTerminatorStyle.maximumLineHeight, bodyStyle.maximumLineHeight)
        XCTAssertEqual(
            text.attribute(.baselineOffset, at: firstRange.upperBound, effectiveRange: nil) as? CGFloat,
            2
        )
    }

    func testImageAttachmentDoesNotInheritTheFixedBodyLineHeight() throws {
        let text = layout.attributedText
        let imageRange = try XCTUnwrap(layout.range(forBlockID: imageBlockID))
        let imageStyle = try XCTUnwrap(
            text.attribute(.paragraphStyle, at: imageRange.location, effectiveRange: nil) as? NSParagraphStyle
        )

        XCTAssertEqual(imageStyle.minimumLineHeight, 0)
        XCTAssertEqual(imageStyle.maximumLineHeight, 0)
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
