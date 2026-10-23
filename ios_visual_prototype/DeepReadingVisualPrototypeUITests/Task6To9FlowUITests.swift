import XCTest

final class Task6To9FlowUITests: XCTestCase {
    func testReaderUsesSystemNavigationBarForTopChrome() throws {
        let app = try launchSeededReader()

        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))

        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(
            navigationBar.waitForExistence(timeout: 4),
            "The reader top chrome must be hosted by the system navigation bar."
        )
        XCTAssertFalse(
            navigationBar.buttons["reader-back"].exists,
            "The reader must use NavigationStack's native back item instead of inserting a custom leading toolbar button."
        )
        XCTAssertTrue(navigationBar.buttons.firstMatch.exists)
        XCTAssertTrue(navigationBar.buttons["reader-open-summary"].exists)
        XCTAssertTrue(
            navigationBar.staticTexts["每日推文"].exists,
            "The reader must expose its real centered title through the system navigation bar."
        )
    }

    func testReaderHidesSystemNavigationBarWhileAssetCardIsPresented() throws {
        let app = try launchSeededReader()
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 8))

        let standaloneNote = app.buttons["独立笔记"]
        XCTAssertTrue(standaloneNote.waitForExistence(timeout: 8))
        standaloneNote.tap()

        XCTAssertTrue(app.otherElements["reading-asset-card"].waitForExistence(timeout: 5))
        XCTAssertTrue(navigationBar.exists, "The covered reader navigation bar must remain mounted.")
        XCTAssertFalse(navigationBar.isHittable, "The full-screen asset card must intercept navigation-bar interaction.")

        let cardScrim = app.otherElements["reading-asset-card"]
        cardScrim.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.20)).tap()
        XCTAssertTrue(
            navigationBar.waitForExistence(timeout: 5),
            "Closing an empty full-screen asset card must reveal the unchanged reader navigation bar."
        )
    }

    func testSummaryHidesSystemNavigationBarWhileAssetCardIsPresented() throws {
        let app = try launchSeededReader()
        let summaryButton = seededSummaryButton(in: app)
        summaryButton.tap()

        let navigationBar = app.navigationBars["标注与笔记"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 8))
        let asset = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "summary-asset-")
        ).firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 8))
        asset.tap()

        XCTAssertTrue(app.otherElements["reading-asset-card"].waitForExistence(timeout: 5))
        XCTAssertTrue(navigationBar.exists, "The covered summary navigation bar must remain mounted.")
        XCTAssertFalse(navigationBar.isHittable, "The full-screen asset card must intercept navigation-bar interaction.")
    }

    func testFullScreenAssetCardPreservesKeyboardForDiscardConfirmation() throws {
        let app = try launchSeededReader()
        let standaloneNote = app.buttons["独立笔记"]
        XCTAssertTrue(standaloneNote.waitForExistence(timeout: 8))
        standaloneNote.tap()

        let editor = app.textViews["asset-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("待放弃的笔记")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        let cardScrim = app.otherElements["reading-asset-card"]
        cardScrim.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.20)).tap()
        let discardAlert = app.otherElements["asset-discard-confirmation"]
        XCTAssertTrue(discardAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["继续编辑"].exists)
        XCTAssertTrue(app.buttons["放弃编辑"].exists)
        XCTAssertTrue(
            app.keyboards.firstMatch.exists,
            "The discard confirmation must not dismiss a keyboard that was visible before the alert."
        )

        app.buttons["继续编辑"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }

    func testFullScreenAssetCardPreservesKeyboardForDeleteConfirmation() throws {
        let app = try launchSeededReader()
        seededSummaryButton(in: app).tap()

        let asset = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "summary-asset-")
        ).firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 8))
        asset.tap()

        let edit = app.buttons["asset-save"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let editor = app.textViews["asset-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        let delete = app.buttons["asset-delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let deleteAlert = app.otherElements["asset-delete-confirmation"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["取消"].exists)
        XCTAssertTrue(app.buttons["删除"].exists)
        XCTAssertTrue(
            app.keyboards.firstMatch.exists,
            "The delete confirmation must not dismiss a keyboard that was visible before the alert."
        )

        app.buttons["取消"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }

    func testSummaryBackControlReturnsToTheReader() throws {
        let app = try launchSeededReader()

        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))

        let summaryButton = seededSummaryButton(in: app)
        summaryButton.tap()

        let navigationBar = app.navigationBars["标注与笔记"]
        XCTAssertTrue(
            navigationBar.waitForExistence(timeout: 8),
            "汇总页标题必须由始终显示的系统导航栏承载。"
        )

        XCTAssertFalse(navigationBar.buttons["summary-system-back-to-reader"].exists)
        let back = navigationBar.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 4))
        XCTAssertTrue(back.isHittable, "汇总页系统返回控件必须接收点击。")
        back.tap()

        XCTAssertTrue(reader.waitForExistence(timeout: 8))
        XCTAssertFalse(navigationBar.exists)
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

    func testArticleCompletionPresentsReportAndReturnsToItsOrigin() throws {
        let app = try launchReaderWithoutSeeding()
        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))

        let completion = app.buttons["reader-complete-reading"]
        for _ in 0 ..< 16 where !completion.isHittable {
            reader.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(completion.waitForExistence(timeout: 3))
        XCTAssertTrue(completion.isHittable, "完成阅读按钮必须作为文章末尾的真实滚动内容出现。")
        completion.tap()

        let report = app.otherElements["reading-report-overlay"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["reading-report-body-frame"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AI reading report"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let finish = app.buttons["reading-report-finish"]
        XCTAssertTrue(finish.isHittable)
        finish.tap()

        XCTAssertTrue(report.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["knowledge-group-collections"].waitForExistence(timeout: 8))
    }

    private func launchSeededReader() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments.append("-ui-test-open-local-seed-reader")
        app.launchArguments.append("-ui-test-seed-highlight")
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }
        return app
    }

    private func launchReaderWithoutSeeding() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments.append("-ui-test-open-local-seed-reader")
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }
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
        XCTAssertFalse(
            app.buttons["reader-highlight-retry"].exists,
            "The UI-test seed highlight RPC must succeed before opening the summary."
        )
        return button
    }
}
