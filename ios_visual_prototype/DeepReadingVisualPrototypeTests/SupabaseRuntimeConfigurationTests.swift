import XCTest
import SwiftUI
import UIKit
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

    @MainActor
    func testMissingConfigurationRendersErrorAndRetryWithoutFixtureArticle() async throws {
        let recorder = AppRootRenderRecorder()
        let controller = UIHostingController(
            rootView: AppRootView(configurationLoader: {
                throw SupabaseRuntimeConfigurationError.missingValue("SUPABASE_URL")
            }, renderObserver: recorder.record)
        )
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            XCTFail("The test host does not provide a window scene.")
            return
        }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(recorder.elements.contains(.text("无法启动阅读服务")))
        XCTAssertTrue(recorder.elements.contains(.text("Missing required public configuration: SUPABASE_URL.")))
        XCTAssertTrue(recorder.elements.contains(.button("重试")))
        XCTAssertFalse(recorder.elements.contains(.text("1600-2100年的公司简史")))
        XCTAssertFalse(recorder.elements.contains(.text("人类世界，和物理学一样，可以简化为四种根本的力量")))
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

@MainActor
private final class AppRootRenderRecorder {
    private(set) var elements: [AppRootRenderedElement] = []

    func record(_ element: AppRootRenderedElement) {
        elements.append(element)
    }
}
