import XCTest

final class KnowledgeBaseFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    func testReadingFeedPagesAndOpensSelectedArticle() throws {
        app = XCUIApplication()
        app.terminate()
        app.launchArguments.append("-ui-test-open-reading-feed")
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }

        let firstArticle = app.buttons["1600-2100年的公司简史"]
        XCTAssertTrue(firstArticle.waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["每日推文"].waitForExistence(timeout: 4))

        let pageControl = app.descendants(matching: .any)["reading-feed-page-control"]
        XCTAssertTrue(pageControl.waitForExistence(timeout: 4))
        XCTAssertEqual(pageControl.label, "第 1 页，共 4 页")

        let swipeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.84, dy: 0.31))
        let swipeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.31))
        swipeStart.press(forDuration: 0.05, thenDragTo: swipeEnd)

        expectation(
            for: NSPredicate(format: "label == %@", "第 2 页，共 4 页"),
            evaluatedWith: pageControl
        )
        waitForExpectations(timeout: 4)

        let secondArticle = app.buttons["为你的大脑收集训练数据"]
        XCTAssertTrue(secondArticle.waitForExistence(timeout: 4))
        XCTAssertTrue(secondArticle.isHittable)
        secondArticle.tap()

        XCTAssertTrue(app.textViews["reader-text-view"].waitForExistence(timeout: 8))
    }

    func testKnowledgeHomeScrollRevealsItsCompactTitle() throws {
        app = XCUIApplication()
        app.terminate()
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }

        XCTAssertTrue(app.buttons["knowledge-group-collections"].waitForExistence(timeout: 12))
        let firstCollection = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-collection-")
        ).firstMatch
        XCTAssertTrue(
            firstCollection.waitForExistence(timeout: 12),
            "Wait for real list content before asserting a scroll-dependent title state."
        )

        let homeScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(homeScrollView.waitForExistence(timeout: 4))
        homeScrollView.swipeUp()

        let compactTitle = app.staticTexts["知识库"]
        XCTAssertTrue(compactTitle.waitForExistence(timeout: 4))
        XCTAssertLessThan(
            compactTitle.frame.minY,
            90,
            "After scrolling, the compact title must occupy the top 116pt chrome rather than the content area."
        )
    }

    func testPublishedCollectionLoadsItsFourDemoArticleCards() throws {
        app = XCUIApplication()
        app.terminate()
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }

        let publishedCollection = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-collection-")
        ).firstMatch
        XCTAssertTrue(publishedCollection.waitForExistence(timeout: 12))
        XCTAssertEqual(publishedCollection.value as? String, "system")

        publishedCollection.tap()

        let collectionNavigationBar = app.navigationBars["往期推文"]
        XCTAssertTrue(
            collectionNavigationBar.waitForExistence(timeout: 8),
            "合集详情应使用系统 inline 导航栏展示固定标题。"
        )
        XCTAssertTrue(app.staticTexts["1600-2100年的公司简史"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["为你的大脑收集训练数据"].exists)
        XCTAssertTrue(app.staticTexts["达尔文是个“懒虫”，你也应该如此"].exists)
        XCTAssertTrue(app.staticTexts["当我们在聊情商时，到底在聊什么？"].exists)

    }

    func testCollectionDetailCircularBackControlReturnsToKnowledgeHome() throws {
        app = XCUIApplication()
        app.terminate()
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }

        let publishedCollection = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-collection-")
        ).firstMatch
        XCTAssertTrue(publishedCollection.waitForExistence(timeout: 12))
        publishedCollection.tap()
        XCTAssertTrue(app.navigationBars["往期推文"].waitForExistence(timeout: 8))

        let detailNavigationBar = app.navigationBars["往期推文"]
        XCTAssertFalse(detailNavigationBar.buttons["knowledge-system-detail-back"].exists)
        let back = detailNavigationBar.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 8))
        XCTAssertTrue(back.isHittable, "系统返回控件必须接收点击。")
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 8))
    }

    func testSystemTagUsesFixedInlineNavigationBar() throws {
        app = XCUIApplication()
        app.terminate()
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }

        let systemTag = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-tag-")
        ).firstMatch
        XCTAssertTrue(systemTag.waitForExistence(timeout: 12))
        XCTAssertEqual(systemTag.value as? String, "system")
        systemTag.tap()

        let tagNavigationBar = app.navigationBars["摘录与思考"]
        XCTAssertTrue(
            tagNavigationBar.waitForExistence(timeout: 8),
            "标签详情应使用系统 inline 导航栏展示固定标题。"
        )
        let tagScrollView = app.scrollViews.firstMatch
        tagScrollView.swipeUp()
        XCTAssertTrue(
            tagNavigationBar.waitForExistence(timeout: 3),
            "标签详情标题在滚动后仍应固定于系统导航栏。"
        )
    }

    func testTagDetailCircularNavigationControlsPerformTheirActions() throws {
        app = XCUIApplication()
        app.terminate()
        app.launch()
        if app.otherElements["app-root-configuration-error"].waitForExistence(timeout: 3) {
            throw XCTSkip("Local Supabase configuration was not supplied to the built app.")
        }

        let systemTag = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-tag-")
        ).firstMatch
        XCTAssertTrue(systemTag.waitForExistence(timeout: 12))
        systemTag.tap()
        XCTAssertTrue(app.navigationBars["摘录与思考"].waitForExistence(timeout: 8))

        let detailNavigationBar = app.navigationBars["摘录与思考"]
        XCTAssertFalse(detailNavigationBar.buttons["knowledge-system-detail-back"].exists)
        let back = detailNavigationBar.buttons.firstMatch
        let addNote = app.buttons["knowledge-system-open-standalone-note"]
        XCTAssertTrue(back.waitForExistence(timeout: 8))
        XCTAssertTrue(addNote.waitForExistence(timeout: 8))
        XCTAssertTrue(back.isHittable)
        XCTAssertTrue(addNote.isHittable)

        addNote.tap()
        let assetCard = app.otherElements["reading-asset-card"]
        XCTAssertTrue(assetCard.waitForExistence(timeout: 5))
        XCTAssertTrue(detailNavigationBar.exists, "The covered tag navigation bar must remain mounted.")
        XCTAssertFalse(detailNavigationBar.isHittable, "The full-screen asset card must intercept navigation-bar interaction.")
    }

    func testKnowledgeTagAssetCardReturnsFromAnchoredReader() throws {
        try launchWithLocalSupabaseAndSeededHighlight()
        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 12))
        let summaryButton = app.buttons["reader-open-summary"]
        XCTAssertTrue(summaryButton.waitForExistence(timeout: 12))
        expectation(for: NSPredicate(format: "enabled == 1"), evaluatedWith: summaryButton)
        waitForExpectations(timeout: 12)
        XCTAssertFalse(app.buttons["reader-highlight-retry"].exists)
        tapReaderSystemBackButton()
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
        systemTag.tap()
        let asset = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-asset-")
        ).firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 8))
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: asset)
        waitForExpectations(timeout: 3)
        asset.tap()
        let assetCard = app.otherElements["reading-asset-card"]
        XCTAssertTrue(assetCard.waitForExistence(timeout: 3))
        // The close affordance is deliberately visual-free. Tapping the
        // uncovered backdrop keeps the same dismissal behaviour.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.08)).tap()
        XCTAssertTrue(
            assetCard.waitForNonExistence(timeout: 3),
            "The asset-card scrim must be removed before its source control can receive a tap."
        )

        let source = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-source-")
        ).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 3))
        source.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 4))
        tapReaderSystemBackButton()
        XCTAssertTrue(asset.waitForExistence(timeout: 3))
    }

    private func tapReaderSystemBackButton() {
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 4))
        XCTAssertFalse(navigationBar.buttons["reader-back"].exists)
        let backButton = navigationBar.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 4))
        XCTAssertTrue(backButton.isHittable)
        backButton.tap()
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
