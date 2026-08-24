import SwiftUI

struct KnowledgeHomeScreen: View {
    @StateObject private var coordinator: KnowledgeHomeCoordinator
    @State private var scrollOffset: CGFloat = 0

    init(repository: any KnowledgeBaseRepository) {
        _coordinator = StateObject(wrappedValue: KnowledgeHomeCoordinator(repository: repository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("知识库")
                        .font(.system(size: KnowledgeVisualTokens.titleSize, weight: .bold))
                        .foregroundStyle(KnowledgeVisualTokens.primaryText)
                        .padding(.top, 56)
                        .padding(.leading, 24)
                        // The compact title takes over at the beginning of
                        // its upward slide rather than cross-fading with this
                        // scroll title beneath the progressive edge.
                        .opacity(KnowledgeHomeTitleCollapsePolicy.largeTitleOpacity(for: scrollOffset))
                        .animation(nil, value: KnowledgeHomeTitleCollapsePolicy.isCompactTitlePresented(for: scrollOffset))
                    groupHeader(header: .collections, title: "推文合集", expanded: coordinator.collectionsExpanded, toggle: coordinator.toggleCollections)
                        .padding(.top, 20)
                    KnowledgeGroupList(
                        items: coordinator.visibleCollections,
                        isSystem: \.isSystem,
                        title: \.name,
                        itemCount: { $0.visibleArticleCount },
                        accessibilityIdentifier: { KnowledgeAccessibilityIdentifier.collection($0.id) },
                        destination: { .collection($0.id) }
                    )
                    groupHeader(header: .tags, title: "标签", expanded: coordinator.tagsExpanded, toggle: coordinator.toggleTags)
                        .padding(.top, 24)
                    KnowledgeGroupList(
                        items: coordinator.visibleTags,
                        isSystem: \.isSystem,
                        title: \.name,
                        itemCount: { coordinator.tagAssetCounts[$0.id, default: 0] },
                        accessibilityIdentifier: { KnowledgeAccessibilityIdentifier.tag($0.id) },
                        destination: { .tag($0.id) }
                    )
                    Spacer(minLength: 128)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            // GeometryReader preferences can be coalesced while a scroll view
            // is decelerating. Use the platform scroll geometry callback so
            // the compact title follows every real content-offset update.
            .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
                // Only actual upward content travel collapses the title. A
                // magnitude check would also react to an overscroll bounce on
                // a short, still-loading list and falsely reveal the compact
                // title while the large title has not moved under the edge.
                max(0, geometry.contentOffset.y)
            }, action: { _, offset in
                scrollOffset = offset
            })

            knowledgeTopEdge
            Text("知识库")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KnowledgeVisualTokens.primaryText)
                // The ZStack's content begins beneath the 59pt status-area
                // safe area. A 2pt local inset therefore places this title at
                // the Figma y=61 baseline instead of incorrectly at y=120.
                .padding(.top, KnowledgeHomeTitleCollapsePolicy.compactTitleTopInset)
                // This is a scroll-driven upward entrance, not a fade. At
                // the reveal threshold it appears 18pt below final position,
                // then reaches the title bar as the content moves to 51pt.
                .offset(y: KnowledgeHomeTitleCollapsePolicy.compactTitleVerticalOffset(for: scrollOffset))
                .opacity(KnowledgeHomeTitleCollapsePolicy.isCompactTitlePresented(for: scrollOffset) ? 1 : 0)
                .animation(nil, value: KnowledgeHomeTitleCollapsePolicy.isCompactTitlePresented(for: scrollOffset))
                .accessibilityHidden(!KnowledgeHomeTitleCollapsePolicy.isCompactTitlePresented(for: scrollOffset))
                .accessibilityIdentifier("knowledge-home-compact-title")
        }
        .task { await coordinator.load() }
        .overlay(alignment: .bottom) { knowledgeBottomEdge }
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

    @ViewBuilder private var knowledgeTopEdge: some View {
        #if DEBUG
        ReaderTopProgressiveBlur(isVisible: true, height: KnowledgeVisualTokens.progressiveEdgeHeight)
        #else
        LinearGradient(colors: [KnowledgeVisualTokens.background.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: KnowledgeVisualTokens.progressiveEdgeHeight)
            .allowsHitTesting(false)
        #endif
    }

    private var knowledgeBottomEdge: some View {
        LinearGradient(colors: [.clear, KnowledgeVisualTokens.background.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            .frame(height: KnowledgeVisualTokens.progressiveEdgeHeight)
            .allowsHitTesting(false)
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
        case 2...6: return "\(dayDelta)天前"
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
