import XCTest

final class Task6To9FlowUITests: XCTestCase {
    func testSummaryBackControlReturnsToTheReader() throws {
        let app = try launchSeededReader()

        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))

        let summaryButton = seededSummaryButton(in: app)
        summaryButton.tap()

        let title = app.staticTexts["标注与笔记"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))

        let back = app.buttons["summary-back-to-reader"]
        XCTAssertTrue(back.waitForExistence(timeout: 4))
        XCTAssertLessThan(back.frame.minY, 120, "Summary back control must remain in the 116pt top chrome.")
        back.tap()

        XCTAssertTrue(reader.waitForExistence(timeout: 8))
        XCTAssertFalse(title.exists)
    }

    func testReaderAssetSummaryReturnsToAnchoredReader() throws {
        let app = try launchSeededReader()
        // The local Debug configuration is compiled into the app target. Do
        // not move public runtime values through the test runner's process
        // environment: Xcode does not inherit that environment into UI tests.
        // Native TextKit selection handles are not deterministic in XCUITest.
        // DEBUG receives this explicit hook, which calls the production
        // repository's create-highlight RPC for the real local anonymous user.
        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))

        let summaryButton = seededSummaryButton(in: app)
        summaryButton.tap()
        let anchoredEntry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "summary-show-in-article-"))
            .firstMatch
        guard anchoredEntry.waitForExistence(timeout: 8) else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Task F summary without anchored entry"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let summaryRows = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "summary-asset-"))
                .count
            let showsLoadFailure = app.staticTexts["无法加载标注与笔记"].exists
            XCTFail(
                "Expected an anchored entry; summary rows: \(summaryRows), load failure: \(showsLoadFailure)."
            )
            return
        }
        let summaryScreenshot = XCTAttachment(screenshot: app.screenshot())
        summaryScreenshot.name = "Task F current article summary"
        summaryScreenshot.lifetime = .keepAlways
        add(summaryScreenshot)
        anchoredEntry.tap()

        XCTAssertTrue(reader.waitForExistence(timeout: 8))
        XCTAssertTrue(reader.isHittable)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "summary-show-in-article-"))
                .firstMatch
                .exists
        )
    }

    private func launchSeededReader() throws -> XCUIApplication {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["SUPABASE_URL"], let anonKey = environment["SUPABASE_ANON_KEY"] else {
            throw XCTSkip("Local Supabase configuration was not supplied to the UI test runner.")
        }
        let app = XCUIApplication()
        app.launchEnvironment = ["SUPABASE_URL": url, "SUPABASE_ANON_KEY": anonKey]
        app.launchArguments.append("-ui-test-open-local-seed-reader")
        app.launchArguments.append("-ui-test-seed-highlight")
        app.launch()
        return app
    }

    private func seededSummaryButton(in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["reader-open-summary"]
        XCTAssertTrue(button.waitForExistence(timeout: 12))
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == 1"),
            object: button
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 12), .completed)
        return button
    }
}
