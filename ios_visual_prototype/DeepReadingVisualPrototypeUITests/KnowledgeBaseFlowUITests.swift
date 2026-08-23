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
        XCTAssertFalse(app.buttons["reader-highlight-retry"].exists)
        app.buttons["reader-back"].tap()
        expectation(for: NSPredicate(format: "isHittable == false"), evaluatedWith: reader)
        waitForExpectations(timeout: 8)

        // System tags sort before user tags. The UUID-based identifier keeps
        // this independent of display names while the value verifies the
        // required system route semantics.
        let systemTag = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-tag-")
        ).firstMatch
        XCTAssertTrue(systemTag.waitForExistence(timeout: 8))
        XCTAssertEqual(systemTag.value as? String, "system")
        XCTAssertTrue(systemTag.isHittable, "The loaded system tag must be tappable before navigation is asserted.")
        let tagID = systemTag.identifier.replacingOccurrences(of: "knowledge-tag-", with: "")
        systemTag.tap()
        let tagDetail = app.staticTexts["knowledge-tag-detail-\(tagID)"]
        XCTAssertTrue(tagDetail.waitForExistence(timeout: 8))
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
        app.buttons["reader-back"].tap()
        XCTAssertTrue(tagDetail.waitForExistence(timeout: 3))
    }

    private func launchWithLocalSupabaseAndSeededHighlight() throws {
        app = XCUIApplication()
        app.terminate()
        app.launchArguments.append("-ui-test-open-local-seed-reader")
        app.launchArguments.append("-ui-test-seed-highlight")
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }
    }
}
