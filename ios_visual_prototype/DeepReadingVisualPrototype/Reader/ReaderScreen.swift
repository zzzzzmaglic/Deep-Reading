import SwiftUI
import UIKit

/// The only production reader entry point. Preview fixtures remain isolated in
/// `ReaderPrototypeView` and are never selected by the app runtime.
struct ReaderScreen: View {
    let route: ReaderRoute
    let dependencies: ReaderDependencies
    let onOpenSummary: (ReaderRoute) -> Void
    let onFinishReading: () -> Void
    let assetRefreshRevision: Int

    @StateObject private var coordinator: ReaderCoordinator
    @StateObject private var aiCompanion: AICompanionController
    @State private var readingReport: ReadingReportPresentation?
    @State private var isAICompanionPresented = false
    @State private var focusesAIComposerOnPresent = false

    private struct ViewportIdentity: Hashable {
        let route: ReaderRoute
        let scrollRequestRevision: Int
    }

    init(
        route: ReaderRoute,
        dependencies: ReaderDependencies,
        onOpenSummary: @escaping (ReaderRoute) -> Void = { _ in },
        onFinishReading: @escaping () -> Void = {},
        assetRefreshRevision: Int = 0
    ) {
        self.route = route
        self.dependencies = dependencies
        self.onOpenSummary = onOpenSummary
        self.onFinishReading = onFinishReading
        self.assetRefreshRevision = assetRefreshRevision
        _coordinator = StateObject(wrappedValue: ReaderCoordinator(dependencies: dependencies))
        _aiCompanion = StateObject(
            wrappedValue: AICompanionController(repository: dependencies.aiCompanionRepository)
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.973, green: 0.961, blue: 0.937)
                .ignoresSafeArea()

            if let article = coordinator.article {
                readerBody(article: article)
            } else if coordinator.loadFailure != nil {
                VStack(spacing: 14) {
                    Text("无法加载文章")
                        .font(.title3.weight(.semibold))
                    Button("重试") { coordinator.retryLoad() }
                        .buttonStyle(.borderedProminent)
                }
                .accessibilityIdentifier("reader-load-error")
            } else {
                ProgressView("正在加载文章…")
            }
        }
        // The whole reader—not just its UITextView—uses the full Figma canvas.
        // Overlay coordinates must therefore start at the physical top edge.
        .ignoresSafeArea()
        .task(id: route) {
            do {
                try await coordinator.load(route: route)
                aiCompanion.beginSession(articleID: route.articleID)
                #if DEBUG
                await coordinator.seedHighlightForUITestIfRequested()
                #endif
            } catch {
                // The coordinator owns the retryable rendered error state.
            }
        }
        .statusBarHidden(!coordinator.chromeIsVisible)
        .navigationTitle("每日推文")
        .toolbarTitleDisplayMode(.inline)
        .toolbar(coordinator.chromeIsVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onOpenSummary(route)
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .disabled(!coordinator.uiTestHighlightSeedIsReady)
                .accessibilityLabel("标注与笔记")
                .accessibilityIdentifier("reader-open-summary")
            }
        }
        .preferredColorScheme(.light)
        .readingReportPresentation(item: $readingReport) { presentation in
            ReadingReportOverlay(
                presentation: presentation,
                onFinish: finishReading
            )
        }
        .readingAssetCardPresentation(item: assetCardPresentation) { presentation in
            ReadingAssetCard(
                draft: presentation.draft,
                repository: dependencies.readingAssetRepository,
                token: presentation.token,
                originalChromeState: presentation.originalChromeState,
                initiallyPresentsTags: presentation.initiallyPresentsTags,
                showsBackdrop: false,
                close: { token, chromeState in
                    coordinator.dismissAssetCard(token: token, restoring: chromeState)
                },
                onSuccessfulSave: {
                    coordinator.completeAssetCardSave(
                        token: presentation.token,
                        restoring: presentation.originalChromeState
                    )
                },
                onSuccessfulDelete: { assetID in
                    coordinator.completeAssetCardDelete(
                        assetID,
                        token: presentation.token,
                        restoring: presentation.originalChromeState
                    )
                },
                onSuccessfulTagUpdate: {
                    coordinator.completeAssetCardTagUpdate(token: presentation.token)
                }
            )
            .id(presentation.token)
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isAICompanionPresented) {
            AICompanionSheet(
                controller: aiCompanion,
                focusesComposerOnAppear: focusesAIComposerOnPresent
            )
            .presentationDetents([.fraction(0.6), .large])
        }
        .task(id: assetRefreshRevision) {
            guard assetRefreshRevision > 0 else { return }
            await coordinator.refreshAssets()
        }
    }

    @ViewBuilder
    private func readerBody(article: Article) -> some View {
        let layout = ReaderTextLayout(article: article, image: UIImage(named: "FourForces"))
        let highlights = coordinator.assets.compactMap { $0.anchor }
        let requestedScrollRequest = coordinator.initialPosition.flatMap { position in
            layout.range(for: position).map { range in
                ReaderScrollRequest(route: route, range: range)
            }
        }

        ReaderTextView(
            layout: layout,
            highlights: highlights,
            documentRevision: ReaderTextDocumentRevision(
                articleID: article.id,
                contentChecksum: article.contentChecksum,
                highlights: highlights
            ),
            requestedScrollRequest: requestedScrollRequest,
            onVisibleUTF16Location: coordinator.queueProgress,
            onScrollDirection: coordinator.handleScroll,
            onBodyTap: coordinator.handleBodyTap,
            onInitialScrollApplied: coordinator.consumeInitialPosition,
            selectedText: { try? layout.selectedText(for: $0) },
            normalizedSelection: layout.normalizedSourceSelection,
            isStandaloneLayoutSelection: layout.isStandaloneLayoutSelection,
            highlightedAnchorAt: { location in
                layout.highlightedAnchor(at: location, among: highlights)
            },
            highlightedAnchorIntersecting: { selection in
                layout.highlightedAnchor(intersecting: selection, among: highlights)
            },
            highlightedAnchorRange: { anchor in
                try? layout.range(for: anchor)
            },
            onSelectionAction: { selection, action in
                Task { @MainActor in
                    if action == .explainWithAI {
                        do {
                            let anchor = try layout.anchor(for: selection)
                            presentAICompanion(reference: AICompanionReference(
                                text: anchor.selectedText,
                                anchor: AICompanionAnchor(
                                    startBlockId: anchor.startBlockID,
                                    endBlockId: anchor.endBlockID
                                ),
                                requestType: .selectionExplain
                            ))
                        } catch {
                            coordinator.recordSelectionFailure(for: action)
                        }
                        return
                    }
                    do {
                        try await coordinator.performSelection(selection, action: action)
                    } catch {
                        coordinator.recordSelectionFailure(for: action)
                    }
                }
            },
            onHighlightedTextAction: { anchor, action in
                Task { @MainActor in
                    if action == .explainWithAI {
                        presentAICompanion(reference: AICompanionReference(
                            text: anchor.selectedText,
                            anchor: AICompanionAnchor(
                                startBlockId: anchor.startBlockID,
                                endBlockId: anchor.endBlockID
                            ),
                            requestType: .highlightExplain
                        ))
                        return
                    }
                    await coordinator.performHighlightedTextAction(anchor, action: action)
                }
            },
            onCompleteReading: {
                beginReadingReport(articleID: article.id)
            },
            showsBottomEdgeEffect: coordinator.chromeIsVisible
        )
        .id(ViewportIdentity(
            route: route,
            scrollRequestRevision: coordinator.scrollRequestRevision
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Keep the text viewport and bottom controls on the full-screen reader
        // canvas. The system navigation bar owns the top chrome and its inset.
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            ReaderBottomScrollEdgeContainer(
                showsReaderChrome: coordinator.chromeIsVisible,
                showsAIControl: true,
                showAssetCard: { _ = coordinator.beginStandaloneNote() },
                showAICompanion: { presentAICompanion(reference: nil) }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 80)
        }
        .overlay(alignment: .bottom) {
            if coordinator.progressFailure != nil || coordinator.selectionFailure != nil || coordinator.assetFailure != nil {
                HStack(spacing: 10) {
                    if coordinator.selectionFailure == .invalidSelection {
                        Text("请选择正文后再划线")
                    } else {
                        Text(
                            coordinator.progressFailure != nil
                                ? "阅读进度未保存"
                                : coordinator.selectionFailure != nil
                                    ? "划线未创建"
                                    : "标注未能刷新"
                        )
                        Button("重试") {
                            if coordinator.progressFailure != nil {
                                coordinator.retryProgress()
                            } else if coordinator.selectionFailure != nil {
                                coordinator.retryHighlightCreation()
                            } else {
                                Task { await coordinator.refreshAssets() }
                            }
                        }
                    }
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 104)
                .accessibilityIdentifier(
                    coordinator.progressFailure != nil
                        ? "reader-progress-retry"
                        : coordinator.selectionFailure != nil
                            ? "reader-highlight-retry"
                            : "reader-assets-retry"
                )
            }
        }
        .animation(.easeInOut(duration: 0.22), value: coordinator.chromeIsVisible)
    }

    private var assetCardPresentation: Binding<ReadingAssetCardPresentation?> {
        Binding(
            get: {
                guard let draft = coordinator.presentedAssetDraft,
                      let chromeState = coordinator.assetCardChromeState,
                      let token = coordinator.assetCardToken else { return nil }
                return ReadingAssetCardPresentation(
                    draft: draft,
                    token: token,
                    originalChromeState: chromeState,
                    initiallyPresentsTags: coordinator.assetCardPresentsTags
                )
            },
            set: { presentation in
                guard presentation == nil,
                      let token = coordinator.assetCardToken,
                      let chromeState = coordinator.assetCardChromeState else { return }
                coordinator.dismissAssetCard(token: token, restoring: chromeState)
            }
        )
    }

    private func finishReading() {
        readingReport = nil
        DispatchQueue.main.async {
            onFinishReading()
        }
    }

    private func beginReadingReport(articleID: UUID) {
        coordinator.showChrome()
        readingReport = ReadingReportPresentation(
            articleID: articleID,
            assetCount: coordinator.assets.count,
            bodyState: .loading
        )

        Task { @MainActor in
            let bodyState: ReadingReportBodyState
            do {
                switch try await dependencies.readingReportGenerator.generateReport(articleID: articleID) {
                case let .generated(body):
                    bodyState = .generated(body)
                case let .unavailable(message):
                    bodyState = .unavailable(message)
                }
            } catch {
                bodyState = .failed("阅读报告暂时无法生成，请稍后再试。")
            }

            guard let current = readingReport, current.articleID == articleID else { return }
            readingReport = current.with(bodyState: bodyState)
        }
    }

    private func presentAICompanion(reference: AICompanionReference?) {
        coordinator.showChrome()
        aiCompanion.prepare(reference: reference)
        focusesAIComposerOnPresent = reference != nil
        isAICompanionPresented = true
    }

}

enum ReadingReportBodyState: Equatable {
    case loading
    case generated(String)
    case unavailable(String)
    case failed(String)

    var text: String? {
        switch self {
        case .loading:
            nil
        case let .generated(text), let .unavailable(text), let .failed(text):
            text
        }
    }
}

struct ReadingReportPresentation: Identifiable, Equatable {
    let articleID: UUID
    let headline: String
    let focusMinutes: Int
    let assetCount: Int
    let conversationCount: Int
    let bodyState: ReadingReportBodyState

    var id: UUID { articleID }

    init(
        articleID: UUID,
        assetCount: Int,
        bodyState: ReadingReportBodyState = .loading
    ) {
        self.articleID = articleID
        headline = ReadingReportMetrics.headline(for: articleID)
        focusMinutes = ReadingReportMetrics.focusMinutes(for: articleID)
        self.assetCount = min(max(assetCount, 0), 99)
        conversationCount = 10
        self.bodyState = bodyState
    }

    func with(bodyState: ReadingReportBodyState) -> ReadingReportPresentation {
        ReadingReportPresentation(
            articleID: articleID,
            assetCount: assetCount,
            bodyState: bodyState
        )
    }
}

enum ReadingReportMetrics {
    private static let fixedHeadlines: [UUID: String] = [
        UUID(uuidString: "10000000-0000-0000-0000-000000000001")!: "从殖民空间，到殖民时间",
        UUID(uuidString: "10000000-0000-0000-0000-000000000004")!: "好的输入，也要适合自己",
        UUID(uuidString: "10000000-0000-0000-0000-000000000005")!: "刻意休息，也是创造的一部分",
        UUID(uuidString: "10000000-0000-0000-0000-000000000006")!: "情商，从理解自己到连接他人"
    ]

    private static let fixedFocusMinutes: [UUID: Int] = [
        UUID(uuidString: "10000000-0000-0000-0000-000000000001")!: 40,
        UUID(uuidString: "10000000-0000-0000-0000-000000000004")!: 20,
        UUID(uuidString: "10000000-0000-0000-0000-000000000005")!: 10,
        UUID(uuidString: "10000000-0000-0000-0000-000000000006")!: 36
    ]

    static func focusMinutes(for articleID: UUID) -> Int {
        fixedFocusMinutes[articleID] ?? 0
    }

    static func headline(for articleID: UUID) -> String {
        fixedHeadlines[articleID] ?? "从殖民空间，到殖民时间"
    }
}

enum ReadingReportLayout {
    static let referenceCanvas = CGSize(width: 393, height: 852)
    static let cardFrame = CGRect(x: 38, y: 215, width: 317, height: 381)
    static let bodyFrame = CGRect(x: 21, y: 109, width: 273, height: 208)
    static let finishButtonOffset = CGPoint(x: 137, y: 327)
    static let bodyFontSize: CGFloat = 13
    static let bodyLineHeight: CGFloat = 20
}

private struct ReadingReportOverlay: View {
    let presentation: ReadingReportPresentation
    let onFinish: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                reportCard
                    .position(
                        x: proxy.size.width / 2,
                        y: max(0, (proxy.size.height - ReadingReportLayout.referenceCanvas.height) / 2)
                            + ReadingReportLayout.cardFrame.midY
                    )
            }
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("reading-report-overlay")
    }

    private var reportCard: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.976, green: 0.976, blue: 0.984)

            metric(
                label: "专注时长",
                value: presentation.focusMinutes,
                suffix: "min"
            )
            .frame(width: 82)
            .position(x: 64, y: 45)

            metric(
                label: "划线笔记",
                value: presentation.assetCount,
                suffix: "处"
            )
            .frame(width: 82)
            .position(x: 159, y: 45)

            metric(
                label: "深度对话",
                value: presentation.conversationCount,
                suffix: "次"
            )
            .frame(width: 82)
            .position(x: 254, y: 45)

            Text("“\(presentation.headline)”")
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .frame(width: 273, height: 21, alignment: .leading)
                .offset(x: 22, y: 80)

            Group {
                if let text = presentation.bodyState.text {
                    ReadingReportBodyText(text: text)
                } else {
                    ProgressView("正在生成阅读报告…")
                        .font(.system(size: ReadingReportLayout.bodyFontSize))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(
                width: ReadingReportLayout.bodyFrame.width,
                height: ReadingReportLayout.bodyFrame.height
            )
            .offset(
                x: ReadingReportLayout.bodyFrame.minX,
                y: ReadingReportLayout.bodyFrame.minY
            )
            .accessibilityIdentifier("reading-report-body-frame")

            Button(action: onFinish) {
                Image(systemName: "checkmark")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(.blue).interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .offset(
                x: ReadingReportLayout.finishButtonOffset.x,
                y: ReadingReportLayout.finishButtonOffset.y
            )
            .accessibilityLabel("完成并返回")
            .accessibilityIdentifier("reading-report-finish")
        }
        .frame(
            width: ReadingReportLayout.cardFrame.width,
            height: ReadingReportLayout.cardFrame.height
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 7, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reading-report-card")
    }

    private func metric(label: String, value: Int, suffix: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.451))

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(value))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                Text(suffix)
                    .font(.system(size: 8))
                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.451))
            }
        }
    }
}

struct ReadingReportBodyText: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> ReadingReportBodyContainerView {
        let view = ReadingReportBodyContainerView()
        let textView = view.textView
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.alwaysBounceVertical = false
        textView.alwaysBounceHorizontal = false
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ReadingReportBodyContainerView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }

    func updateUIView(_ view: ReadingReportBodyContainerView, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineBreakStrategy = [.pushOut]
        paragraph.minimumLineHeight = ReadingReportLayout.bodyLineHeight
        paragraph.maximumLineHeight = ReadingReportLayout.bodyLineHeight
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        view.textView.attributedText = NSAttributedString(
            string: normalizedText,
            attributes: [
                .font: UIFont.systemFont(ofSize: ReadingReportLayout.bodyFontSize),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
        )
        view.textView.setNeedsLayout()
    }

    private var normalizedText: String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(
                of: #"\n[\t ]*\n+"#,
                with: "\n",
                options: .regularExpression
            )
    }
}

final class ReadingReportBodyContainerView: UIView, UITextViewDelegate {
    let textView = ReadingReportBodyTextView(usingTextLayoutManager: false)
    private let scrollIndicator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        textView.delegate = self
        addSubview(textView)

        scrollIndicator.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.55)
        scrollIndicator.layer.cornerRadius = 1
        scrollIndicator.isUserInteractionEnabled = false
        scrollIndicator.isHidden = true
        scrollIndicator.accessibilityIdentifier = "reading-report-body-scroll-indicator"
        addSubview(scrollIndicator)

        textView.overflowStateDidChange = { [weak self] _ in
            self?.updateScrollIndicator()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        updateScrollIndicator()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollIndicator()
    }

    private func updateScrollIndicator() {
        let contentHeight = textView.measuredContentHeight
        let viewportHeight = bounds.height
        guard textView.isScrollEnabled,
              contentHeight > viewportHeight,
              viewportHeight > 0 else {
            scrollIndicator.isHidden = true
            return
        }

        scrollIndicator.isHidden = false
        let indicatorHeight = max(24, viewportHeight * viewportHeight / contentHeight)
        let availableTravel = max(0, viewportHeight - indicatorHeight)
        let maximumOffset = max(1, contentHeight - viewportHeight)
        let progress = min(max(textView.contentOffset.y / maximumOffset, 0), 1)
        scrollIndicator.frame = CGRect(
            x: bounds.maxX + 4,
            y: progress * availableTravel,
            width: 2,
            height: indicatorHeight
        )
    }
}

final class ReadingReportBodyTextView: UITextView {
    var overflowStateDidChange: ((Bool) -> Void)?
    private(set) var measuredContentHeight: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width > 0, bounds.height > 0 else { return }
        let laidOutTextHeight = measuredTextHeight(for: bounds.width)
        measuredContentHeight = laidOutTextHeight
        let needsScrolling = laidOutTextHeight > bounds.height + 0.5

        if isScrollEnabled != needsScrolling {
            isScrollEnabled = needsScrolling
            if !needsScrolling {
                contentOffset = .zero
            }
        }
        showsVerticalScrollIndicator = false
        overflowStateDidChange?(needsScrolling)
    }

    private func measuredTextHeight(for width: CGFloat) -> CGFloat {
        let sizingContainer = NSTextContainer(
            size: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        sizingContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        sizingContainer.lineBreakMode = textContainer.lineBreakMode
        sizingContainer.maximumNumberOfLines = 0

        let sizingLayoutManager = NSLayoutManager()
        sizingLayoutManager.addTextContainer(sizingContainer)
        let sizingStorage = NSTextStorage(attributedString: attributedText ?? NSAttributedString())
        sizingStorage.addLayoutManager(sizingLayoutManager)
        sizingLayoutManager.ensureLayout(for: sizingContainer)
        return ceil(sizingLayoutManager.usedRect(for: sizingContainer).height)
    }
}

extension ReaderRoute {
    /// The immutable local Supabase seed article, not a reader fixture.
    static let localSeed = ReaderRoute(
        articleID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        anchorID: nil,
        origin: .feed
    )
}
