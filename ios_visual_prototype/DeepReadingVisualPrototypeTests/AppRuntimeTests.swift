import SwiftUI
import Supabase
import UIKit
import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class AppRuntimeTests: XCTestCase {
    func testReaderRegistersItsTextViewportForTheSystemTopScrollEdge() async throws {
        let articleID = UUID()
        let article = Article(
            id: articleID,
            title: "导航栏背景",
            sourceName: "测试",
            contentChecksum: "navigation-background",
            blocks: [
                ArticleBlock(
                    id: UUID(),
                    articleID: articleID,
                    position: 0,
                    content: "阅读器显示顶部控件时，系统导航栏必须绘制标准背景材质。",
                    kind: .paragraph
                )
            ]
        )
        let screen = NavigationStack {
            ReaderScreen(
                route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed),
                dependencies: ReaderDependencies(
                    articleRepository: ReaderScreenFixtureArticleRepository(article: article),
                    readingAssetRepository: ReaderScreenFixtureAssetRepository()
                )
            )
        }
        let controller = UIHostingController(rootView: screen)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()

        let textView = try await waitForTextView(in: controller.view)
        let owner = try XCTUnwrap(owningViewController(of: textView))

        XCTAssertTrue(
            owner.contentScrollView(for: .top) === textView,
            "The reader must explicitly register its UIViewRepresentable text viewport so UIKit can produce the native top scroll-edge blur."
        )
    }

    func testSummaryRegistersItsListScrollViewForTheSystemTopScrollEdge() async throws {
        let articleID = UUID()
        let article = Article(
            id: articleID,
            title: "汇总页导航栏背景",
            sourceName: "测试",
            contentChecksum: "summary-navigation-background",
            blocks: [
                ArticleBlock(
                    id: UUID(),
                    articleID: articleID,
                    position: 0,
                    content: "汇总页列表必须驱动系统顶部导航栏的滚动边缘状态。",
                    kind: .paragraph
                )
            ]
        )
        let assets = (0 ..< 6).map { index in
            ReadingAsset(
                articleID: articleID,
                anchor: nil,
                noteContent: "第 \(index + 1) 条独立笔记，用于生成可滚动的汇总列表。"
            )
        }
        let screen = NavigationStack {
            ArticleAssetSummaryScreen(
                articleID: articleID,
                origin: .feed,
                dependencies: ReaderDependencies(
                    articleRepository: ReaderScreenFixtureArticleRepository(article: article),
                    readingAssetRepository: ReaderScreenFixtureAssetRepository(assets: assets)
                ),
                showInArticle: { _ in },
                refreshReaderAssets: {}
            )
        }
        let controller = UIHostingController(rootView: screen)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        let scrollView = try await waitForScrollableView(in: controller.view)
        let owner = try XCTUnwrap(owningViewController(of: scrollView))

        XCTAssertTrue(
            owner.contentScrollView(for: .top) === scrollView,
            "The summary list must explicitly register its scroll view so the system navigation bar uses the same top scroll-edge layout as the reader."
        )
    }

    func testReaderShowsDailyTweetAsItsSystemNavigationTitle() async throws {
        let articleID = UUID()
        let article = Article(
            id: articleID,
            title: "这不是导航标题",
            sourceName: "测试",
            contentChecksum: "reader-navigation-title",
            blocks: [
                ArticleBlock(
                    id: UUID(),
                    articleID: articleID,
                    position: 0,
                    content: "阅读器需要真实的居中系统导航标题。",
                    kind: .paragraph
                )
            ]
        )
        let screen = NavigationStack {
            ReaderScreen(
                route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed),
                dependencies: ReaderDependencies(
                    articleRepository: ReaderScreenFixtureArticleRepository(article: article),
                    readingAssetRepository: ReaderScreenFixtureAssetRepository()
                )
            )
        }
        let controller = UIHostingController(rootView: screen)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        let titleLabel = try await waitForLabel(text: "每日推文", in: controller.view)

        XCTAssertEqual(titleLabel.text, "每日推文")
        XCTAssertNotNil(
            owningNavigationBar(of: titleLabel),
            "The reader title must be rendered by the system navigation bar rather than by an in-content overlay."
        )
    }

    func testAppRootBootstrapsInjectedRuntimeAndRendersReadyState() async throws {
        let runtime = FakeRuntime()
        let recorder = AppRuntimeRenderRecorder()
        let controller = UIHostingController(rootView: AppRootView(configurationLoader: { try self.configuration() }, runtimeBuilder: { _ in runtime }, renderObserver: recorder.record))
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(75))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.layoutIfNeeded()
        XCTAssertEqual(runtime.bootstrapCalls, 1)
        XCTAssertTrue(recorder.elements.contains(.text("Knowledge runtime ready")))
    }

    func testAppRootRendersRetryWhenRuntimeBootstrapFails() async throws {
        let runtime = FakeRuntime(error: FakeRuntimeError.bootstrapFailed)
        let recorder = AppRuntimeRenderRecorder()
        let controller = UIHostingController(rootView: AppRootView(configurationLoader: { try self.configuration() }, runtimeBuilder: { _ in runtime }, renderObserver: recorder.record))
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(75))
        XCTAssertTrue(recorder.elements.contains(.text("无法连接阅读服务")))
        XCTAssertTrue(recorder.elements.contains(.button("重试")))
    }

    func testActualRuntimeKeepsOneClientForServicesAfterRootReachesReady() async throws {
        var client: SupabaseClient? = makeClient()
        weak var retainedClient = client
        var runtime: AppRuntime? = AppRuntime(client: try XCTUnwrap(client), sessionBootstrap: {})
        weak var retainedRuntime = runtime
        let recorder = AppRuntimeRenderRecorder()
        let controller = UIHostingController(rootView: AppRootView(
            configurationLoader: { try self.configuration() },
            runtimeBuilder: { _ in runtime! },
            renderObserver: recorder.record
        ))
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(client)), try XCTUnwrap(runtime?.sessionStore.clientIdentity))
        XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(client)), try XCTUnwrap(runtime?.articleRepository.clientIdentity))
        XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(client)), try XCTUnwrap(runtime?.readingAssetRepository.clientIdentity))

        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(75))
        runtime = nil
        client = nil
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertTrue(recorder.elements.contains(.text("Knowledge runtime ready")))
        XCTAssertNotNil(retainedRuntime)
        XCTAssertNotNil(retainedClient)
    }

    func testKnowledgeRuntimeSharesClientAndKnowledgeIsTheDefaultTab() throws {
        let client = makeClient()
        let runtime = AppRuntime(client: client, sessionBootstrap: {})

        XCTAssertEqual(ObjectIdentifier(client), try XCTUnwrap(runtime.knowledgeRepository.clientIdentity))
        XCTAssertEqual(AppTab.defaultSelection, .knowledge)
    }

    func testOnlyTheExplicitUITestArgumentSeedsTheKnowledgeReader() {
        XCTAssertEqual(KnowledgeNavigationInitialPath.destinations(arguments: []), [])
        XCTAssertEqual(
            KnowledgeNavigationInitialPath.destinations(arguments: ["-ui-test-open-local-seed-reader"]),
            [.reader(ReaderRoute(articleID: ReaderRoute.localSeed.articleID, anchorID: nil, origin: .knowledge))]
        )
    }

    func testReadingReportUsesTheFourFixedDemoDurationsAndFigmaBodyGeometry() {
        let articleIDs = [
            UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
            UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        ]

        XCTAssertEqual(articleIDs.map { ReadingReportMetrics.focusMinutes(for: $0) }, [40, 20, 10, 36])
        XCTAssertEqual(ReadingReportLayout.cardFrame, CGRect(x: 38, y: 215, width: 317, height: 381))
        XCTAssertEqual(ReadingReportLayout.bodyFrame, CGRect(x: 21, y: 109, width: 273, height: 208))
        XCTAssertEqual(ReadingReportLayout.finishButtonOffset, CGPoint(x: 137, y: 327))
        XCTAssertEqual(
            ReadingReportLayout.cardFrame.height
                - ReadingReportLayout.finishButtonOffset.y
                - 44,
            10
        )
        XCTAssertEqual(
            ReadingReportLayout.finishButtonOffset.y
                - ReadingReportLayout.bodyFrame.maxY,
            10
        )
        XCTAssertEqual(ReadingReportLayout.bodyFontSize, 13)
        XCTAssertEqual(ReadingReportLayout.bodyLineHeight, 20)
    }

    func testReadingReportBodyUsesItsFigmaWidthAndWrapsChineseText() throws {
        let report = ReadingReportBodyText(
            text: "Edison，早上读完这篇四十分钟的公司简史，你抓住了一条很实在的线索。你从周报自动化切入，注意到省下的半小时又被顺手接来的任务填满，进而追问效率收益到底归谁。"
        )
        .frame(
            width: ReadingReportLayout.bodyFrame.width,
            height: ReadingReportLayout.bodyFrame.height
        )
        let controller = UIHostingController(rootView: report)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }
        controller.view.frame = CGRect(
            origin: .zero,
            size: ReadingReportLayout.bodyFrame.size
        )
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()

        let textView = try XCTUnwrap(findTextView(in: controller.view))
        textView.layoutIfNeeded()
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        var lineCount = 0
        textView.layoutManager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: textView.layoutManager.numberOfGlyphs)
        ) { _, _, _, _, _ in
            lineCount += 1
        }

        XCTAssertEqual(textView.bounds.width, ReadingReportLayout.bodyFrame.width, accuracy: 0.5)
        XCTAssertEqual(textView.textContainer.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(textView.textStorage.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle != nil, true)
        XCTAssertGreaterThan(lineCount, 1)
    }

    func testReadingReportBodyCollapsesBlankLinesBetweenThreeParts() throws {
        let report = ReadingReportBodyText(text: "第一部分。\n\n第二部分。\n   \n第三部分。")
            .frame(
                width: ReadingReportLayout.bodyFrame.width,
                height: ReadingReportLayout.bodyFrame.height
            )
        let controller = UIHostingController(rootView: report)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }
        controller.view.frame = CGRect(origin: .zero, size: ReadingReportLayout.bodyFrame.size)
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()

        let textView = try XCTUnwrap(findTextView(in: controller.view))
        XCTAssertEqual(textView.text, "第一部分。\n第二部分。\n第三部分。")
        let paragraph = try XCTUnwrap(
            textView.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                as? NSParagraphStyle
        )
        XCTAssertEqual(paragraph.paragraphSpacing, 0)
        XCTAssertEqual(paragraph.paragraphSpacingBefore, 0)
        XCTAssertTrue(paragraph.lineBreakStrategy.contains(.pushOut))
    }

    func testReadingReportBodyOnlyScrollsWhenContentOverflows() throws {
        let shortBody = try makeReadingReportBodyTextView(text: "第一部分。\n第二部分。\n第三部分。")
        XCTAssertFalse(shortBody.textView.isScrollEnabled)
        XCTAssertFalse(shortBody.textView.showsVerticalScrollIndicator)
        XCTAssertTrue(shortBody.indicator.isHidden)

        let longText = Array(repeating: "这是一段用于验证阅读报告正文超出固定区域后能够继续向下滑动查看的内容。", count: 24)
            .joined()
        let longBody = try makeReadingReportBodyTextView(text: longText)
        XCTAssertTrue(longBody.textView.isScrollEnabled)
        XCTAssertFalse(longBody.textView.showsVerticalScrollIndicator)
        XCTAssertFalse(longBody.indicator.isHidden)
        XCTAssertGreaterThan(longBody.textView.contentSize.height, longBody.textView.bounds.height)
        XCTAssertGreaterThan(longBody.indicator.frame.minX, longBody.textView.frame.maxX)
    }

    func testReadingReportGeneratorMapsGeneratedAndUnavailableResponses() async throws {
        let articleID = UUID()
        let generated = SupabaseReadingReportGenerator(
            remote: StubReadingReportRemote(
                response: SupabaseReadingReportResponse(
                    status: "generated",
                    body: "  一段有依据的阅读报告。\n",
                    message: nil
                )
            )
        )
        let unavailable = SupabaseReadingReportGenerator(
            remote: StubReadingReportRemote(
                response: SupabaseReadingReportResponse(
                    status: "unavailable",
                    body: nil,
                    message: "当前没有可用于生成阅读报告的笔记。"
                )
            )
        )

        let generatedResult = try await generated.generateReport(articleID: articleID)
        let unavailableResult = try await unavailable.generateReport(articleID: articleID)
        XCTAssertEqual(generatedResult, .generated("一段有依据的阅读报告。"))
        XCTAssertEqual(
            unavailableResult,
            .unavailable("当前没有可用于生成阅读报告的笔记。")
        )
    }

    func testReadingReportPresentationKeepsIdentityWhileBodyLoads() {
        let articleID = UUID()
        let loading = ReadingReportPresentation(
            articleID: articleID,
            assetCount: 3,
            bodyState: .loading
        )
        let completed = loading.with(bodyState: .generated("报告正文"))

        XCTAssertEqual(completed.id, loading.id)
        XCTAssertEqual(completed.bodyState, .generated("报告正文"))
        XCTAssertEqual(completed.assetCount, 3)
    }

    func testReaderCompletionControlUsesFigmaSizeAndInvokesItsAction() {
        let textView = ReaderTextView.ReaderViewportTextView(frame: .zero, textContainer: nil)
        var completed = false
        textView.onCompleteReading = { completed = true }

        textView.completionButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(completed)
        XCTAssertEqual(ReaderCompletionControlLayout.size, 47)
    }

    func testReadingReportUsesImmediateContentAndAssetCardStyleDimming() {
        XCTAssertEqual(ReadingOverlayTransitionStyle.readingReport.dimmingOpacity, 0.20)
        XCTAssertFalse(ReadingOverlayTransitionStyle.readingReport.animatesDismissal)
        XCTAssertEqual(ReadingOverlayTransitionStyle.assetCard.dimmingOpacity, 0.16)
        XCTAssertTrue(ReadingOverlayTransitionStyle.assetCard.animatesDismissal)
    }

    func testKnowledgeInteractionIdentifiersUseStableUUIDs() {
        let id = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!

        XCTAssertEqual(KnowledgeAccessibilityIdentifier.collection(id), "knowledge-collection-20000000-0000-0000-0000-000000000001")
        XCTAssertEqual(KnowledgeAccessibilityIdentifier.tag(id), "knowledge-tag-20000000-0000-0000-0000-000000000001")
    }

    func testReaderUsesAScrollableViewportAndKeepsOffsetWhenChromeHides() async throws {
        let articleID = UUID()
        let blocks = (0 ..< 18).map { index in
            ArticleBlock(
                id: UUID(), articleID: articleID, position: index,
                content: "第\(index) 段：阅读器滚动视口必须保留用户当前位置，不能在控件隐藏时回弹到顶部。",
                kind: .paragraph
            )
        }
        let article = Article(
            id: articleID,
            title: "可滚动阅读器",
            sourceName: "测试",
            contentChecksum: "viewport-check",
            blocks: blocks
        )
        let screen = ReaderScreen(
            route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed),
            dependencies: ReaderDependencies(
                articleRepository: ReaderScreenFixtureArticleRepository(article: article),
                readingAssetRepository: ReaderScreenFixtureAssetRepository()
            )
        )
        let controller = UIHostingController(rootView: screen)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(160))
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()

        let textView = try XCTUnwrap(findTextView(in: controller.view))
        XCTAssertNil(textView.textLayoutManager, "Reader must use TextKit 1 before any scroll callback runs.")
        XCTAssertTrue(textView.isScrollEnabled)
        XCTAssertTrue(textView.panGestureRecognizer.isEnabled)
        XCTAssertGreaterThan(textView.contentSize.height, textView.bounds.height + 40)

        for point in [CGPoint(x: 196, y: 380), CGPoint(x: 196, y: 610)] {
            let hitView = try XCTUnwrap(controller.view.hitTest(point, with: nil))
            XCTAssertTrue(
                hitView === textView || hitView.isDescendant(of: textView),
                "正文点 \(point) 被 \(type(of: hitView)) 接收，而不是 UITextView"
            )
        }

        textView.delegate?.scrollViewWillBeginDragging?(textView)
        textView.setContentOffset(CGPoint(x: 0, y: 180), animated: false)
        textView.delegate?.scrollViewDidEndDragging?(textView, willDecelerate: false)
        try await Task.sleep(for: .milliseconds(500))

        let retainedTextView = try XCTUnwrap(findTextView(in: controller.view))
        XCTAssertEqual(retainedTextView.contentOffset.y, 180, accuracy: 1)
    }

    func testAnchoredReaderRoutePlacesTargetBelowTopChrome() async throws {
        let articleID = UUID()
        let blocks = (0 ..< 14).map { index in
            ArticleBlock(
                id: UUID(),
                articleID: articleID,
                position: index,
                content: "第\(index) 段：用于验证从汇总页返回后，阅读器会将指定标注定位在顶部控件和虚化遮罩的下方，而不是只滚到刚好可见的位置。",
                kind: .paragraph
            )
        }
        let article = Article(
            id: articleID,
            title: "锚点定位",
            sourceName: "测试",
            contentChecksum: "anchor-placement",
            blocks: blocks
        )
        let targetBlock = blocks[10]
        let anchor = TextAnchor(
            id: UUID(),
            assetID: UUID(),
            articleID: articleID,
            startBlockID: targetBlock.id,
            endBlockID: targetBlock.id,
            startUTF16Offset: 0,
            endUTF16Offset: 6,
            selectedText: "第10段：用于",
            contentChecksum: article.contentChecksum
        )
        let screen = ReaderScreen(
            route: ReaderRoute(articleID: articleID, anchorID: anchor.id, origin: .feed),
            dependencies: ReaderDependencies(
                articleRepository: ReaderScreenFixtureArticleRepository(article: article),
                readingAssetRepository: ReaderScreenFixtureAssetRepository(
                    assets: [ReadingAsset(anchor: anchor, noteContent: nil)]
                )
            )
        )
        let controller = UIHostingController(rootView: screen)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        let layout = ReaderTextLayout(article: article, image: nil)
        let targetRange = try XCTUnwrap(layout.range(for: ReaderPosition(blockID: targetBlock.id, utf16Offset: 0)))
        let textView = try await waitForTextView(
            in: controller.view,
            highlighting: targetRange.location
        )
        let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: targetRange, actualCharacterRange: nil)
        let targetRect = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
        let targetViewportY = targetRect.minY + textView.textContainerInset.top - textView.contentOffset.y

        XCTAssertGreaterThanOrEqual(targetViewportY, 148)
        XCTAssertLessThanOrEqual(
            targetViewportY,
            220,
            "A route anchor must be placed directly below the reader top chrome, not merely made visible at the lower edge."
        )
    }

    func testReaderTextViewportExecutesExplicitAnchorRequestAfterLayout() async throws {
        let articleID = UUID()
        let blocks = (0 ..< 12).map { index in
            ArticleBlock(
                id: UUID(),
                articleID: articleID,
                position: index,
                content: "第\(index) 段：用于隔离验证真实 UITextView 是否会在拥有有效视口后执行显式锚点定位请求。",
                kind: .paragraph
            )
        }
        let article = Article(
            id: articleID,
            title: "直接定位",
            sourceName: "测试",
            contentChecksum: "direct-anchor-request",
            blocks: blocks
        )
        let layout = ReaderTextLayout(article: article, image: nil)
        let targetRange = try XCTUnwrap(layout.range(for: ReaderPosition(blockID: blocks[9].id, utf16Offset: 0)))
        var didApplyRequest = false
        let reader = ReaderTextView(
            layout: layout,
            highlights: [],
            documentRevision: ReaderTextDocumentRevision(
                articleID: article.id,
                contentChecksum: article.contentChecksum,
                highlights: []
            ),
            requestedScrollRequest: ReaderScrollRequest(
                route: ReaderRoute(articleID: articleID, anchorID: UUID(), origin: .feed),
                range: targetRange
            ),
            onVisibleUTF16Location: { _ in },
            onScrollDirection: { _ in },
            onBodyTap: {},
            onInitialScrollApplied: { didApplyRequest = true },
            selectedText: { try? layout.selectedText(for: $0) },
            normalizedSelection: layout.normalizedSourceSelection,
            isStandaloneLayoutSelection: layout.isStandaloneLayoutSelection,
            highlightedAnchorAt: { _ in nil },
            highlightedAnchorIntersecting: { _ in nil },
            highlightedAnchorRange: { _ in nil },
            onSelectionAction: { _, _ in },
            onHighlightedTextAction: { _, _ in },
            onCompleteReading: {},
            showsBottomEdgeEffect: true
        )
        let controller = UIHostingController(rootView: reader.frame(width: 393, height: 852))
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()

        XCTAssertTrue(didApplyRequest)
    }

    func testActualReaderSwipeReceivesTheSimulatorGesture() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["SUPABASE_URL"], let anonKey = environment["SUPABASE_ANON_KEY"] else {
            throw XCTSkip("Local Supabase configuration was not supplied to the diagnostic UI test.")
        }

        let app = XCUIApplication(bundleIdentifier: "com.deepreading.visualprototype")
        app.launchEnvironment = ["SUPABASE_URL": url, "SUPABASE_ANON_KEY": anonKey]
        app.launch()

        let reader = app.textViews["reader-text-view"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        reader.swipeUp()

        XCTAssertFalse(
            app.buttons["返回"].waitForExistence(timeout: 1),
            "A real upward swipe must reach UITextView and hide reader chrome."
        )
    }

    private func makeReadingReportBodyTextView(text: String) throws -> (
        textView: UITextView,
        indicator: UIView
    ) {
        let report = ReadingReportBodyText(text: text)
            .frame(
                width: ReadingReportLayout.bodyFrame.width,
                height: ReadingReportLayout.bodyFrame.height
            )
        let controller = UIHostingController(rootView: report)
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }
        controller.view.frame = CGRect(origin: .zero, size: ReadingReportLayout.bodyFrame.size)
        controller.loadViewIfNeeded()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let textView = try XCTUnwrap(findTextView(in: controller.view))
        for _ in 0 ..< 3 {
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
        }
        let indicator = try XCTUnwrap(
            findView(
                accessibilityIdentifier: "reading-report-body-scroll-indicator",
                in: controller.view
            )
        )
        return (textView, indicator)
    }

    private func configuration() throws -> SupabaseRuntimeConfiguration {
        try SupabaseRuntimeConfiguration.load(values: ["SUPABASE_URL": "http://127.0.0.1:54321", "SUPABASE_ANON_KEY": "test-key"])
    }

    private func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "test-key"
        )
    }

    private func makeWindow(rootViewController: UIViewController) throws -> UIWindow {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { throw XCTSkip("The test host does not provide a window scene.") }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        return window
    }

    private func findTextView(in view: UIView) -> UITextView? {
        if let textView = view as? UITextView { return textView }
        for subview in view.subviews {
            if let textView = findTextView(in: subview) { return textView }
        }
        return nil
    }

    private func findView(accessibilityIdentifier: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == accessibilityIdentifier { return view }
        for subview in view.subviews {
            if let match = findView(accessibilityIdentifier: accessibilityIdentifier, in: subview) {
                return match
            }
        }
        return nil
    }

    private func findLabel(text: String, in view: UIView) -> UILabel? {
        if let label = view as? UILabel, label.text == text { return label }
        for subview in view.subviews {
            if let label = findLabel(text: text, in: subview) { return label }
        }
        return nil
    }

    private func findScrollableView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView,
           scrollView.contentSize.height > scrollView.bounds.height {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = findScrollableView(in: subview) { return scrollView }
        }
        return nil
    }

    private func owningNavigationBar(of view: UIView) -> UINavigationBar? {
        var ancestor = view.superview
        while let current = ancestor {
            if let navigationBar = current as? UINavigationBar { return navigationBar }
            ancestor = current.superview
        }
        return nil
    }

    private func owningViewController(of view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    private func waitForTextView(in view: UIView) async throws -> UITextView {
        for _ in 0 ..< 50 {
            if let textView = findTextView(in: view) { return textView }
            try await Task.sleep(for: .milliseconds(20))
        }
        return try XCTUnwrap(findTextView(in: view))
    }

    private func waitForLabel(text: String, in view: UIView) async throws -> UILabel {
        for _ in 0 ..< 50 {
            if let label = findLabel(text: text, in: view) { return label }
            try await Task.sleep(for: .milliseconds(20))
        }
        return try XCTUnwrap(findLabel(text: text, in: view))
    }

    private func waitForScrollableView(in view: UIView) async throws -> UIScrollView {
        for _ in 0 ..< 50 {
            if let scrollView = findScrollableView(in: view) { return scrollView }
            try await Task.sleep(for: .milliseconds(20))
        }
        return try XCTUnwrap(findScrollableView(in: view))
    }

    private func waitForTextView(
        in view: UIView,
        highlighting location: Int
    ) async throws -> UITextView {
        for _ in 0 ..< 50 {
            if let textView = findTextView(in: view),
               textView.attributedText.attribute(
                .readerHighlightTint,
                at: location,
                effectiveRange: nil
               ) != nil {
                return textView
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        let textView = try XCTUnwrap(findTextView(in: view))
        XCTAssertNotNil(
            textView.attributedText.attribute(.readerHighlightTint, at: location, effectiveRange: nil),
            "The anchored asset must reach ReaderScreen before its return-to-article scroll is evaluated."
        )
        return textView
    }
}

private enum FakeRuntimeError: Error { case bootstrapFailed }
private final class FakeRuntime: AppRuntimeBootstrapping, @unchecked Sendable {
    private let error: Error?
    private(set) var bootstrapCalls = 0
    init(error: Error? = nil) { self.error = error }
    func bootstrap() async throws { bootstrapCalls += 1; if let error { throw error } }
}

private final class ReaderScreenFixtureArticleRepository: ArticleRepository, @unchecked Sendable {
    private let article: Article

    init(article: Article) { self.article = article }
    func readArticle(id: UUID) async throws -> Article { article }
    func readProgress(articleID: UUID) async throws -> ReaderPosition? { nil }
}

private actor ReaderScreenFixtureAssetRepository: ReadingAssetRepository {
    private let assets: [ReadingAsset]

    init(assets: [ReadingAsset] = []) {
        self.assets = assets
    }

    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] { assets }
    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset { throw FixtureError.unsupported }
    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset { throw FixtureError.unsupported }
    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset { throw FixtureError.unsupported }
    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {}
    func deleteReadingAsset(id: UUID) async throws {}
    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws {}
    func readTags() async throws -> [Tag] { [] }
    func createTag(name: String) async throws -> Tag { throw FixtureError.unsupported }
    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset { throw FixtureError.unsupported }
    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset { throw FixtureError.unsupported }
}

private enum FixtureError: Error { case unsupported }

private struct StubReadingReportRemote: SupabaseReadingReportRemote {
    let response: SupabaseReadingReportResponse

    func generate(articleID: UUID) async throws -> SupabaseReadingReportResponse {
        response
    }
}

@MainActor private final class AppRuntimeRenderRecorder {
    private(set) var elements: [AppRootRenderedElement] = []
    func record(_ element: AppRootRenderedElement) { elements.append(element) }
}
