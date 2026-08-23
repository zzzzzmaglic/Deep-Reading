import XCTest

final class KnowledgeBaseFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    func testKnowledgeTagAssetCardReturnsFromAnchoredReader() throws {
        try launchWithLocalSupabaseAndSeededHighlight()
        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))
        let summaryButton = app.buttons["reader-open-summary"]
        XCTAssertTrue(summaryButton.waitForExistence(timeout: 12))
        expectation(for: NSPredicate(format: "enabled == 1"), evaluatedWith: summaryButton)
        waitForExpectations(timeout: 12)
        app.buttons["返回"].tap()
        XCTAssertTrue(app.otherElements["knowledge-home"].waitForExistence(timeout: 8))

        let systemTag = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-tag-")
        ).firstMatch
        XCTAssertTrue(systemTag.waitForExistence(timeout: 8))
        let tagID = systemTag.identifier.replacingOccurrences(of: "knowledge-tag-", with: "")
        systemTag.tap()
        let asset = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-asset-")
        ).firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 8))
        asset.tap()
        XCTAssertTrue(app.otherElements["reading-asset-card"].waitForExistence(timeout: 3))
        app.buttons["asset-card-dismiss"].tap()

        let source = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-source-")
        ).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        source.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 4))
        app.buttons["返回"].tap()
        XCTAssertTrue(app.otherElements["knowledge-tag-detail-\(tagID)"].waitForExistence(timeout: 3))
    }

    private func launchWithLocalSupabaseAndSeededHighlight() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["SUPABASE_URL"], let anonKey = environment["SUPABASE_ANON_KEY"] else {
            throw XCTSkip("Local Supabase configuration was not supplied to the UI test runner.")
        }
        app = XCUIApplication()
        // Values are forwarded only at runtime and are never persisted in the
        // UI test source or its launch arguments.
        app.launchEnvironment = ["SUPABASE_URL": url, "SUPABASE_ANON_KEY": anonKey]
        app.launchArguments.append("-ui-test-open-local-seed-reader")
        app.launchArguments.append("-ui-test-seed-highlight")
        app.launch()
    }
}
