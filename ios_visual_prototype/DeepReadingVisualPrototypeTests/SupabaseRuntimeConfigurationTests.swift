import XCTest
@testable import DeepReadingVisualPrototype

final class SupabaseRuntimeConfigurationTests: XCTestCase {
    func testLoadRejectsMissingPublicConfiguration() {
        XCTAssertThrowsError(try SupabaseRuntimeConfiguration.load(values: [:])) { error in
            XCTAssertEqual(error as? SupabaseRuntimeConfigurationError, .missingValue("SUPABASE_URL"))
        }
    }

    func testReadingAssetDerivesLinkedNoteOnlyWhenItHasAnchorAndNote() {
        let anchor = TextAnchor(
            id: UUID(),
            assetID: UUID(),
            articleID: UUID(),
            startBlockID: UUID(),
            endBlockID: UUID(),
            startUTF16Offset: 0,
            endUTF16Offset: 2,
            selectedText: "摘录",
            contentChecksum: "checksum"
        )

        XCTAssertEqual(ReadingAsset(anchor: anchor, noteContent: nil).kind, .highlight)
        XCTAssertEqual(ReadingAsset(anchor: anchor, noteContent: "想法").kind, .linkedNote)
        XCTAssertEqual(ReadingAsset(anchor: nil, noteContent: "想法").kind, .standaloneNote)
    }
}
