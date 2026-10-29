import SwiftUI

struct KnowledgeHomeScreen: View {
    @StateObject private var coordinator: KnowledgeHomeCoordinator

    init(repository: any KnowledgeBaseRepository) {
        _coordinator = StateObject(wrappedValue: KnowledgeHomeCoordinator(repository: repository))
    }

    var body: some View {
        ZStack {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    groupHeader(header: .collections, title: "推文合集", expanded: coordinator.collectionsExpanded, toggle: coordinator.toggleCollections)
                        .padding(.top, 8)
                    KnowledgeGroupList(
                        items: coordinator.visibleCollections,
                        isSystem: \.isSystem,
                        title: \.name,
                        itemCount: { $0.visibleArticleCount },
                        accessibilityIdentifier: { KnowledgeAccessibilityIdentifier.collection($0.id) },
                        destination: { .collection(id: $0.id, title: $0.name) }
                    )
                    groupHeader(header: .tags, title: "标签", expanded: coordinator.tagsExpanded, toggle: coordinator.toggleTags)
                        .padding(.top, 24)
                    KnowledgeGroupList(
                        items: coordinator.visibleTags,
                        isSystem: \.isSystem,
                        title: \.name,
                        itemCount: { coordinator.tagAssetCounts[$0.id, default: 0] },
                        accessibilityIdentifier: { KnowledgeAccessibilityIdentifier.tag($0.id) },
                        destination: { .tag(id: $0.id, title: $0.name) }
                    )
                    Spacer(minLength: 128)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .navigationTitle("知识库")
            .toolbarTitleDisplayMode(.large)
        }
        .task { await coordinator.load() }
    }

    private func groupHeader(header: KnowledgeHomeHeader, title: String, expanded: Bool, toggle: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: KnowledgeHomeHeaderPolicy.titleToDisclosureOverlap) {
                Text(title)
                    .font(.system(size: KnowledgeVisualTokens.sectionTitleSize, weight: .bold))
                    .fixedSize()
                Button(action: toggle) {
                    Image("KnowledgeDisclosure")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: KnowledgeHomeHeaderPolicy.disclosureGlyphSize,
                            height: KnowledgeHomeHeaderPolicy.disclosureGlyphSize
                        )
                        .rotationEffect(.degrees(KnowledgeHomeHeaderPolicy.disclosureRotationDegrees(isExpanded: expanded)))
                        .offset(x: KnowledgeHomeHeaderPolicy.disclosureVisualOffsetX)
                        .frame(
                            width: KnowledgeHomeHeaderPolicy.disclosureHitArea,
                            height: KnowledgeHomeHeaderPolicy.disclosureHitArea
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("knowledge-group-\(KnowledgeHomeHeaderPolicy.toggleTarget(for: header).rawValue)")
                .accessibilityLabel(expanded ? "收起\(title)" : "展开\(title)")
                .animation(.easeInOut(duration: 0.18), value: expanded)
            }
            .frame(height: KnowledgeHomeHeaderPolicy.disclosureHitArea, alignment: .leading)
            Spacer(minLength: 0)
            Image("KnowledgeAdd")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
        }
        .foregroundStyle(KnowledgeVisualTokens.primaryText)
        .padding(.leading, 24)
        .padding(.trailing, 28)
        .frame(height: KnowledgeHomeHeaderPolicy.disclosureHitArea)
        .padding(.bottom, 3)
        // This header has a stable identity. Only the glyph rotation receives
        // an animation; inserting rows therefore does not redraw the title.
    }

}

private struct KnowledgeGroupList<Item: Identifiable>: View {
    let items: [Item]
    let isSystem: KeyPath<Item, Bool>
    let title: KeyPath<Item, String>
    let itemCount: (Item) -> Int
    let accessibilityIdentifier: (Item) -> String
    let destination: (Item) -> KnowledgeNavigationDestination

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                NavigationLink(value: destination(item)) {
                    HStack(spacing: 12) {
                        Text(item[keyPath: title]).font(.system(size: 16, weight: item[keyPath: isSystem] ? .medium : .regular))
                        Spacer()
                        if itemCount(item) > 0 {
                            Text("\(itemCount(item))")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(KnowledgeVisualTokens.secondaryText)
                                .frame(minWidth: 24, alignment: .trailing)
                        }
                        Image(systemName: item[keyPath: isSystem] ? "lock.fill" : "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(KnowledgeVisualTokens.secondaryText)
                            .frame(width: 16, height: 16)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: rowHeight(for: item))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityIdentifier(item))
                .accessibilityValue(item[keyPath: isSystem] ? "system" : "user")
                if item.id != items.last?.id { Divider().padding(.horizontal, 16).overlay(KnowledgeVisualTokens.divider) }
            }
        }
        .frame(width: KnowledgeVisualTokens.groupWidth)
        .background(.white, in: RoundedRectangle(cornerRadius: KnowledgeVisualTokens.groupCornerRadius))
        .padding(.horizontal, KnowledgeVisualTokens.pageInset)
    }

    private func rowHeight(for item: Item) -> CGFloat {
        item.id == items.last?.id ? KnowledgeVisualTokens.rowHeight - 4 : KnowledgeVisualTokens.rowHeight
    }
}

enum KnowledgeRelativeDate {
    static func displayText(for date: Date, now: Date, calendar: Calendar) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let dayDelta = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0
        switch dayDelta {
        case ...0: return "今天"
        case 1: return "昨天"
        case 2...6:
            let chineseNumerals = [2: "两", 3: "三", 4: "四", 5: "五", 6: "六"]
            return "\(chineseNumerals[dayDelta] ?? "\(dayDelta)")天前"
        case 7...13: return "一周前"
        default:
            let year = calendar.component(.year, from: date)
            let currentYear = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            return year == currentYear ? "\(month)月\(day)日" : "\(year)年\(month)月\(day)日"
        }
    }
}

struct ReadingFeedScreen: View {
    @StateObject private var coordinator: ReadingFeedCoordinator
    let openArticle: (KnowledgeArticlePreview) -> Void

    init(
        repository: any KnowledgeBaseRepository,
        openArticle: @escaping (KnowledgeArticlePreview) -> Void
    ) {
        _coordinator = StateObject(wrappedValue: ReadingFeedCoordinator(repository: repository))
        self.openArticle = openArticle
    }

    var body: some View {
        ZStack {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("每日推文")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(KnowledgeVisualTokens.primaryText)
                        .frame(
                            width: ReadingFeedLayout.sectionTitleWidth,
                            height: ReadingFeedLayout.sectionTitleHeight,
                            alignment: .topLeading
                        )
                        .padding(.leading, 20)
                        .padding(.bottom, ReadingFeedLayout.dailyTitleBottomSpacing)
                        .accessibilityIdentifier("reading-feed-daily-title")
                    dailyReadingPager
                    Text("认知漫游")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(KnowledgeVisualTokens.primaryText)
                        .frame(height: 27, alignment: .topLeading)
                        .padding(.leading, 20)
                        .padding(.top, 19)
                        .padding(.bottom, 9)
                    RoundedRectangle(cornerRadius: ReadingFeedLayout.cardCornerRadius)
                        .fill(.white)
                        .frame(
                            width: ReadingFeedLayout.cardWidth,
                            height: ReadingFeedLayout.cognitiveRoamingHeight
                        )
                        .shadow(color: .black.opacity(0.06), radius: 11, x: 0, y: 10)
                        .padding(.horizontal, 11)
                        .accessibilityIdentifier("reading-feed-cognitive-roaming-placeholder")
                    Spacer(minLength: 128)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, ReadingFeedLayout.dailyTitleTopInset)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .navigationTitle("首页")
        .toolbarTitleDisplayMode(.large)
        .task { await coordinator.load() }
    }

    @ViewBuilder
    private var dailyReadingPager: some View {
        if coordinator.articles.isEmpty {
            RoundedRectangle(cornerRadius: ReadingFeedLayout.cardCornerRadius)
                .fill(.white)
                .frame(width: ReadingFeedLayout.cardWidth, height: ReadingFeedLayout.dailyCardHeight)
                .shadow(color: .black.opacity(0.06), radius: 11, x: 0, y: 10)
                .padding(.horizontal, 11)
                .overlay {
                    if coordinator.failure != nil {
                        Button("重试") { Task { await coordinator.load() } }
                            .buttonStyle(.bordered)
                    } else {
                        ProgressView()
                    }
                }
        } else {
            ZStack(alignment: .top) {
                TabView(selection: $coordinator.selectedPage) {
                    ForEach(Array(coordinator.articles.enumerated()), id: \.element.id) { index, article in
                        ReadingFeedArticleCard(
                            article: article,
                            open: { openArticle(article) }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("reading-feed-daily-pager")

                pageControl
                    .frame(maxWidth: .infinity)
                    .padding(.top, 195)
                    .allowsHitTesting(false)
            }
            .frame(height: ReadingFeedLayout.dailyCardHeight)
        }
    }

    private var pageControl: some View {
        HStack(spacing: ReadingFeedLayout.pageDotSpacing) {
            ForEach(coordinator.articles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.primary.opacity(index == coordinator.selectedPage ? 1 : 0.3))
                    .frame(
                        width: ReadingFeedLayout.pageDotDiameter,
                        height: ReadingFeedLayout.pageDotDiameter
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("reading-feed-page-control")
        .accessibilityLabel(
            "第 \(coordinator.selectedPage + 1) 页，共 \(coordinator.articles.count) 页"
        )
    }
}

private struct ReadingFeedArticleCard: View {
    let article: KnowledgeArticlePreview
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: ReadingFeedLayout.cardCornerRadius)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 11, x: 0, y: 10)

                Image(article.coverAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: ReadingFeedLayout.coverWidth, height: ReadingFeedLayout.coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: ReadingFeedLayout.coverCornerRadius))
                    .shadow(color: Color(hex: 0x595959), radius: 4, x: 3, y: 3)
                    .padding(.leading, 13)
                    .padding(.top, 13)

                VStack(alignment: .leading, spacing: 0) {
                    Text(article.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(KnowledgeVisualTokens.primaryText)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(width: ReadingFeedLayout.titleWidth, height: 42, alignment: .topLeading)
                    metadata
                        .padding(.top, 13)
                }
                .padding(.leading, 111)
                .padding(.top, 18)

                RoundedRectangle(cornerRadius: 5)
                    .fill(KnowledgeVisualTokens.background)
                    .frame(
                        width: ReadingFeedLayout.introductionWidth,
                        height: ReadingFeedLayout.introductionHeight
                    )
                    .padding(.leading, 10)
                    .padding(.top, 105)

                Text(ReadingFeedArticleIntroduction.text(for: article.title))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: 0x6C6C72))
                    .lineSpacing(2)
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(width: 324, height: 64, alignment: .topLeading)
                    .padding(.leading, 22)
                    .padding(.top, 114)
                    .accessibilityIdentifier("reading-feed-article-introduction")

            }
            .frame(width: ReadingFeedLayout.cardWidth, height: ReadingFeedLayout.dailyCardHeight)
            .contentShape(RoundedRectangle(cornerRadius: ReadingFeedLayout.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reading-feed-article-\(article.id.uuidString)")
        .accessibilityLabel(article.title)
    }

    private var metadata: some View {
        HStack(spacing: 0) {
            metadataGroup(symbol: "folder.circle", text: article.sourceName)
            Spacer().frame(width: 14)
            metadataGroup(symbol: "eye.circle", text: article.cognitiveDimension)
            Spacer(minLength: 0)
            Text(KnowledgeRelativeDate.displayText(for: article.publishedAt, now: Date(), calendar: .current))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: 0x6C6C72).opacity(0.54))
                .lineLimit(1)
        }
        .frame(width: 224, height: 15, alignment: .leading)
    }

    private func metadataGroup(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 13, height: 13)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(Color(hex: 0xB0B0B3))
    }

}
