import XCTest
@testable import DeepReadingVisualPrototype

final class SupabaseRuntimeConfigurationTests: XCTestCase {
    func testLoadRejectsMissingPublicConfiguration() {
        XCTAssertThrowsError(try SupabaseRuntimeConfiguration.load(values: [:])) { error in
            XCTAssertEqual(error as? SupabaseRuntimeConfigurationError, .missingValue("SUPABASE_URL"))
        }
    }

    func testLoadRejectsBlankEnvironmentValueWithoutFallingBackToBundle() {
        XCTAssertThrowsError(
            try SupabaseRuntimeConfiguration.load(
                environment: ["SUPABASE_URL": "   "],
                bundleValues: validBundleValues
            )
        ) { error in
            XCTAssertEqual(error as? SupabaseRuntimeConfigurationError, .missingValue("SUPABASE_URL"))
        }
    }

    func testLoadRejectsUnexpandedEnvironmentPlaceholder() {
        XCTAssertThrowsError(
            try SupabaseRuntimeConfiguration.load(
                environment: ["SUPABASE_URL": "$(SUPABASE_URL)"],
                bundleValues: validBundleValues
            )
        ) { error in
            XCTAssertEqual(error as? SupabaseRuntimeConfigurationError, .missingValue("SUPABASE_URL"))
        }
    }

    func testLoadRejectsBlankBundleValueWhenEnvironmentIsMissing() {
        XCTAssertThrowsError(
            try SupabaseRuntimeConfiguration.load(
                environment: [:],
                bundleValues: [
                    "SUPABASE_URL": "https://bundle.example.test",
                    "SUPABASE_ANON_KEY": "\n",
                ]
            )
        ) { error in
            XCTAssertEqual(error as? SupabaseRuntimeConfigurationError, .missingValue("SUPABASE_ANON_KEY"))
        }
    }

    func testLoadRejectsUnexpandedBundlePlaceholderWhenEnvironmentIsMissing() {
        XCTAssertThrowsError(
            try SupabaseRuntimeConfiguration.load(
                environment: [:],
                bundleValues: [
                    "SUPABASE_URL": "$(SUPABASE_URL)",
                    "SUPABASE_ANON_KEY": "bundle-key",
                ]
            )
        ) { error in
            XCTAssertEqual(error as? SupabaseRuntimeConfigurationError, .missingValue("SUPABASE_URL"))
        }
    }

    func testLoadPrefersEnvironmentValuesOverBundleValues() throws {
        let configuration = try SupabaseRuntimeConfiguration.load(
            environment: [
                "SUPABASE_URL": "http://127.0.0.1:54321",
                "SUPABASE_ANON_KEY": "environment-key",
            ],
            bundleValues: validBundleValues
        )

        XCTAssertEqual(configuration.url, URL(string: "http://127.0.0.1:54321"))
        XCTAssertEqual(configuration.anonKey, "environment-key")
    }

    func testConfigurationFailureScreenShowsRetryWithoutFixtureArticle() {
        let screen = AppRootScreen.configurationFailure(.missingValue("SUPABASE_URL"))

        XCTAssertTrue(screen.showsRetry)
        XCTAssertFalse(screen.displaysFixtureArticle)
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

    private var validBundleValues: [String: String?] {
        [
            "SUPABASE_URL": "https://bundle.example.test",
            "SUPABASE_ANON_KEY": "bundle-key",
        ]
    }
}
