import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class KnowledgeHomeCoordinatorTests: XCTestCase {
    func testCollapsedGroupsShowOnlyFiveAndFixedEntriesSortFirst() async {
        let repository = HomeTestKnowledgeRepository(
            snapshot: .init(
                collections: [
                    collection(name: "D"), collection(name: "往期推文", isSystem: true),
                    collection(name: "B"), collection(name: "F"), collection(name: "A"), collection(name: "C"),
                ],
                tags: [tag(name: "写作"), tag(name: "摘录与思考", isSystem: true), tag(name: "人物"), tag(name: "产品"), tag(name: "决策"), tag(name: "商业")]
            )
        )
        let coordinator = KnowledgeHomeCoordinator(repository: repository)

        await coordinator.load()

        XCTAssertEqual(coordinator.visibleCollections.map(\.name), ["往期推文", "A", "B", "C", "D"])
        XCTAssertEqual(coordinator.visibleTags.first?.name, "摘录与思考")
        XCTAssertFalse(coordinator.collectionsExpanded)
        XCTAssertFalse(coordinator.tagsExpanded)
    }

    func testRecreatedHomeReturnsToIndependentCollapsedGroups() {
        let repository = HomeTestKnowledgeRepository(snapshot: .init(collections: [], tags: []))
        let coordinator = KnowledgeHomeCoordinator(repository: repository)

        coordinator.toggleCollections()

        XCTAssertTrue(coordinator.collectionsExpanded)
        let recreated = KnowledgeHomeCoordinator(repository: repository)
        XCTAssertFalse(recreated.collectionsExpanded)
        XCTAssertFalse(recreated.tagsExpanded)
    }

    func testRelativeDateUsesFixedCalendarBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(2026, 8, 23, 12, 0, calendar: calendar)

        XCTAssertEqual(KnowledgeRelativeDate.displayText(for: date(2026, 8, 23, 0, 1, calendar: calendar), now: now, calendar: calendar), "今天")
        XCTAssertEqual(KnowledgeRelativeDate.displayText(for: date(2026, 8, 22, 23, 59, calendar: calendar), now: now, calendar: calendar), "昨天")
        XCTAssertEqual(KnowledgeRelativeDate.displayText(for: date(2026, 8, 20, 12, 0, calendar: calendar), now: now, calendar: calendar), "三天前")
        XCTAssertEqual(KnowledgeRelativeDate.displayText(for: date(2026, 8, 16, 12, 0, calendar: calendar), now: now, calendar: calendar), "一周前")
        XCTAssertEqual(KnowledgeRelativeDate.displayText(for: date(2026, 1, 1, 12, 0, calendar: calendar), now: now, calendar: calendar), "1月1日")
        XCTAssertEqual(KnowledgeRelativeDate.displayText(for: date(2025, 12, 31, 12, 0, calendar: calendar), now: now, calendar: calendar), "2025年12月31日")
    }

    func testEachGroupHeaderUsesTheFigmaDisclosureGeometryAndDirection() {
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.disclosureHitArea, 44)
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.disclosureGlyphSize, 22)
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.titleToDisclosureOverlap, -11)
        XCTAssertFalse(KnowledgeHomeHeaderPolicy.hasFullRowTapTarget)
        // A right chevron means the compact, five-item state can be expanded;
        // a down chevron means the full group is currently shown.
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.disclosureRotationDegrees(isExpanded: false), 0)
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.disclosureRotationDegrees(isExpanded: true), 90)
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.disclosureVisualOffsetX, 1)
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.toggleTarget(for: .collections), .collections)
        XCTAssertEqual(KnowledgeHomeHeaderPolicy.toggleTarget(for: .tags), .tags)
        XCTAssertTrue(KnowledgeTabBarPolicy.usesNativeLiquidGlass)
        XCTAssertEqual(KnowledgeTabBarPolicy.itemCount, 2)
        XCTAssertTrue(KnowledgeTabBarPolicy.hasMovingSelectionPill)
        XCTAssertEqual(KnowledgeTabBarPolicy.selectedContentTintHex, 0x007AFF)
        XCTAssertFalse(KnowledgeTabBarPolicy.usesVendoredUnionTabView)
        XCTAssertTrue(KnowledgeTabBarPolicy.retainsVendoredUnionTabViewForAB)
        XCTAssertEqual(KnowledgeTabBarPolicy.vendoredSourceTag, "1.2.0")
        XCTAssertEqual(
            KnowledgeTabBarPolicy.vendoredSourceRevision,
            "abf9afc364b315d1d058975c6ebbfabde6be06ea"
        )
        XCTAssertTrue(KnowledgeTabBarPolicy.usesNativeSegmentedControlSelection)
        XCTAssertTrue(KnowledgeTabBarPolicy.usesUIKitInteractiveGlassSurface)
        XCTAssertTrue(KnowledgeTabBarPolicy.placesContentOverlayAboveUIKitSurface)
        XCTAssertFalse(KnowledgeTabBarPolicy.usesPrivateAPI)
        XCTAssertEqual(KnowledgeVisualTokens.tabBarWidth, 185)
        XCTAssertEqual(KnowledgeVisualTokens.tabBarHeight, 62)
        XCTAssertEqual(KnowledgeVisualTokens.tabBarItemWidth, 88.5)
        XCTAssertEqual(KnowledgeVisualTokens.tabBarItemHeight, 54)
        XCTAssertEqual(KnowledgeVisualTokens.tabBarBottomInset, 20)
        XCTAssertTrue(KnowledgeTabBarPolicy.usesSingleSynchronousSelectionBinding)
        XCTAssertTrue(KnowledgeTabBarPolicy.usesNativeTabViewContentHost)
        XCTAssertTrue(KnowledgeTabBarPolicy.usesBottomSafeAreaInsetHost)
        XCTAssertFalse(KnowledgeTabBarPolicy.usesOpacitySwitchedFullScreenLayers)
        XCTAssertFalse(KnowledgeTabBarPolicy.usesNativeSelectionItemBounce)
        XCTAssertTrue(KnowledgeTabBarPolicy.usesUIKitSelectionItemBounce)
        XCTAssertEqual(KnowledgeTabBarPolicy.selectionItemBouncePeakScale, 1.20)
    }

    func testKnowledgeHomeUsesTheSystemLargeTitleNavigationChrome() {
        XCTAssertTrue(KnowledgeHomeNavigationBarPolicy.usesSystemLargeTitle)
        XCTAssertTrue(KnowledgeHomeNavigationBarPolicy.usesSystemScrollEdgeMaterial)
        XCTAssertFalse(KnowledgeHomeNavigationBarPolicy.usesCustomScrollTitleTracking)
        XCTAssertFalse(KnowledgeHomeNavigationBarPolicy.usesCustomTopProgressiveEdge)
        XCTAssertTrue(KnowledgeTabBarPolicy.usesSingleAnimationDriver)
        XCTAssertEqual(KnowledgeDetailLayout.contentTopInset, 123)
        XCTAssertTrue(KnowledgeDetailLayout.usesFullScreenCoordinateSpace)
        XCTAssertEqual(KnowledgeDetailLayout.collectionCardSpacing, 5)
        XCTAssertEqual(KnowledgeDetailLayout.tagAssetSpacing, 8)
    }

    func testCollectionArticleCardKeepsItsTitleAndDateOnOneSharedRightEdge() {
        XCTAssertEqual(KnowledgeDetailLayout.collectionTitleTextWidth, 224)
    }

    func testReadingFeedLoadsTheSystemCollectionInItsExistingArticleOrder() async {
        let archive = collection(name: "往期推文", isSystem: true)
        let expected = [
            article(title: "第一篇"),
            article(title: "第二篇"),
            article(title: "第三篇"),
            article(title: "第四篇"),
        ]
        let repository = HomeTestKnowledgeRepository(
            snapshot: .init(collections: [collection(name: "普通合集"), archive], tags: []),
            articles: expected
        )
        let coordinator = ReadingFeedCoordinator(repository: repository)

        await coordinator.load()

        XCTAssertEqual(coordinator.articles.map(\.title), expected.map(\.title))
        XCTAssertEqual(coordinator.selectedPage, 0)
        XCTAssertNil(coordinator.failure)
    }

    func testReadingFeedUsesFigma28CardAndFourDotGeometry() {
        XCTAssertEqual(ReadingFeedLayout.sectionTitleWidth, 86)
        XCTAssertEqual(ReadingFeedLayout.sectionTitleHeight, 27)
        XCTAssertEqual(ReadingFeedLayout.dailyTitleTopInset, 9)
        XCTAssertEqual(ReadingFeedLayout.dailyTitleBottomSpacing, 12)
        XCTAssertEqual(ReadingFeedLayout.cardWidth, 371)
        XCTAssertEqual(
            ReadingFeedLayout.titleWidth,
            KnowledgeDetailLayout.collectionTitleTextWidth
        )
        XCTAssertEqual(ReadingFeedLayout.dailyCardHeight, 210)
        XCTAssertEqual(ReadingFeedLayout.cognitiveRoamingHeight, 200)
        XCTAssertEqual(ReadingFeedLayout.introductionWidth, 347)
        XCTAssertEqual(ReadingFeedLayout.introductionHeight, 82)
        XCTAssertEqual(ReadingFeedLayout.pageDotDiameter, 8)
        XCTAssertEqual(ReadingFeedLayout.pageDotSpacing, 8)
        XCTAssertEqual(ReadingFeedLayout.articleCount, 4)
    }

    func testReadingFeedProvidesIntroductionsForAllFourDemoArticles() {
        let titles = [
            "1600-2100年的公司简史",
            "为你的大脑收集训练数据",
            "达尔文是个“懒虫”，你也应该如此",
            "当我们在聊情商时，到底在聊什么？",
        ]

        XCTAssertTrue(titles.allSatisfy { !ReadingFeedArticleIntroduction.text(for: $0).isEmpty })
        XCTAssertEqual(ReadingFeedArticleIntroduction.text(for: "未知文章"), "")
    }

    func testTabBarABVariantRequiresAnExplicitDiagnosticArgument() {
        XCTAssertEqual(
            TabBarABVariant.from(arguments: ["-tab-bar-ab-upstream"]),
            .upstream
        )
        XCTAssertEqual(
            TabBarABVariant.from(arguments: ["-tab-bar-ab-helper"]),
            .helper
        )
        XCTAssertEqual(
            TabBarABVariant.from(arguments: ["-tab-bar-ab-segmented"]),
            .segmented
        )
        XCTAssertEqual(
            TabBarABVariant.from(arguments: ["-tab-bar-ab-uikit-interactive"]),
            .uikitInteractive
        )
        XCTAssertNil(TabBarABVariant.from(arguments: []))
    }

    func testSeedCoverAssetNamesAreAllExportedKnowledgeCovers() {
        XCTAssertEqual(KnowledgeCoverAssetName.seedArticleAssetNames, ["KnowledgeCover1", "KnowledgeCover2", "KnowledgeCover3"])
        XCTAssertTrue(KnowledgeCoverAssetName.seedArticleAssetNames.allSatisfy(KnowledgeCoverAssetName.isExported))
    }

    private func collection(name: String, isSystem: Bool = false) -> KnowledgeCollection {
        KnowledgeCollection(id: UUID(), name: name, description: nil, isSystem: isSystem, visibleArticleCount: 0)
    }

    private func tag(name: String, isSystem: Bool = false) -> Tag {
        Tag(id: UUID(), ownerID: UUID(), name: name, isSystem: isSystem)
    }

    private func article(title: String) -> KnowledgeArticlePreview {
        KnowledgeArticlePreview(
            id: UUID(),
            title: title,
            sourceName: "每日推文",
            coverAssetName: "KnowledgeCover1",
            cognitiveDimension: "方法论",
            publishedAt: Date(timeIntervalSince1970: 0),
            readingAssetCount: 0
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

private actor HomeTestKnowledgeRepository: KnowledgeBaseRepository {
    let snapshot: KnowledgeHomeSnapshot
    let articles: [KnowledgeArticlePreview]

    init(snapshot: KnowledgeHomeSnapshot, articles: [KnowledgeArticlePreview] = []) {
        self.snapshot = snapshot
        self.articles = articles
    }

    func readHome() async throws -> KnowledgeHomeSnapshot { snapshot }
    func readCollection(id: UUID) async throws -> KnowledgeCollection { throw CancellationError() }
    func readCollectionArticles(collectionID: UUID) async throws -> [KnowledgeArticlePreview] { articles }
    func readArticleTitles(ids: Set<UUID>) async throws -> [UUID: String] { [:] }
    func removeArticlesFromCollection(collectionID: UUID, articleIDs: [UUID]) async throws {}
}
