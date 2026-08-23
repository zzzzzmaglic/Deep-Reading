import XCTest

final class KnowledgeBaseFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    func testKnowledgeTabOpensTagAssetCardAndReturnsFromAnchoredReader() throws {
        try launchWithLocalSupabaseAndSeededAsset()
        app.tabBars.buttons["知识库"].tap()
        app.buttons["knowledge-tag-摘录与思考"].tap()

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
        XCTAssertTrue(app.textViews["reader-text-view"].waitForExistence(timeout: 4))
        app.buttons["返回"].tap()
        XCTAssertTrue(app.buttons["knowledge-tag-摘录与思考"].waitForExistence(timeout: 3))
    }

    private func launchWithLocalSupabaseAndSeededAsset() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["SUPABASE_URL"], let anonKey = environment["SUPABASE_ANON_KEY"] else {
            throw XCTSkip("Local Supabase configuration was not supplied to the UI test runner.")
        }
        app = XCUIApplication()
        // Values are forwarded only at runtime and are never persisted in the
        // UI test source or its launch arguments.
        app.launchEnvironment = ["SUPABASE_URL": url, "SUPABASE_ANON_KEY": anonKey]
        app.launch()
        XCTAssertTrue(app.otherElements["knowledge-home"].waitForExistence(timeout: 12))
    }
}
