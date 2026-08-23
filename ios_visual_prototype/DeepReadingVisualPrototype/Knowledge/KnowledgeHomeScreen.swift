import SwiftUI

struct KnowledgeHomeScreen: View {
    @StateObject private var coordinator: KnowledgeHomeCoordinator
    let openCollection: (KnowledgeCollection) -> Void
    let openTag: (Tag) -> Void
    @State private var compactTitle = false

    init(
        repository: any KnowledgeBaseRepository,
        openCollection: @escaping (KnowledgeCollection) -> Void = { _ in },
        openTag: @escaping (Tag) -> Void = { _ in }
    ) {
        _coordinator = StateObject(wrappedValue: KnowledgeHomeCoordinator(repository: repository))
        self.openCollection = openCollection
        self.openTag = openTag
    }

    var body: some View {
        ZStack(alignment: .top) {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GeometryReader { proxy in
                        Color.clear.preference(key: KnowledgeHomeScrollOffsetKey.self, value: proxy.frame(in: .named("knowledge-home-scroll")).minY)
                    }
                    .frame(height: 0)
                    Text("知识库")
                        .font(.system(size: KnowledgeVisualTokens.titleSize, weight: .bold))
                        .foregroundStyle(KnowledgeVisualTokens.primaryText)
                        .padding(.top, 58)
                        .padding(.leading, 24)
                    groupHeader(header: .collections, title: "推文合集", expanded: coordinator.collectionsExpanded, toggle: coordinator.toggleCollections)
                        .padding(.top, 20)
                    KnowledgeGroupList(
                        items: coordinator.visibleCollections,
                        isSystem: \.isSystem,
                        title: \.name,
                        accessibilityIdentifier: { "knowledge-collection-\($0.id.uuidString)" }
                    ) { collection in
                        openCollection(collection)
                    }
                    groupHeader(header: .tags, title: "标签", expanded: coordinator.tagsExpanded, toggle: coordinator.toggleTags)
                        .padding(.top, 30)
                    KnowledgeGroupList(
                        items: coordinator.visibleTags,
                        isSystem: \.isSystem,
                        title: \.name,
                        accessibilityIdentifier: { "knowledge-tag-\($0.name)" }
                    ) { tag in
                        openTag(tag)
                    }
                    Spacer(minLength: 128)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .coordinateSpace(name: "knowledge-home-scroll")
            .scrollIndicators(.hidden)
            .onPreferenceChange(KnowledgeHomeScrollOffsetKey.self) { compactTitle = $0 < -45 }

            knowledgeTopEdge
            if compactTitle {
                Text("知识库")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(KnowledgeVisualTokens.primaryText)
                    .padding(.top, 61)
            }
        }
        .task { await coordinator.load() }
        .overlay(alignment: .bottom) { knowledgeBottomEdge }
    }

    private func groupHeader(header: KnowledgeHomeHeader, title: String, expanded: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: KnowledgeVisualTokens.sectionTitleSize, weight: .bold))
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                Spacer()
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, minHeight: KnowledgeHomeHeaderPolicy.minimumHitAreaHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("knowledge-group-\(KnowledgeHomeHeaderPolicy.toggleTarget(for: header).rawValue)")
        .accessibilityLabel(expanded ? "收起\(title)" : "展开\(title)")
        .foregroundStyle(KnowledgeVisualTokens.primaryText)
        .padding(.leading, 24)
        .padding(.trailing, 11)
        .frame(height: 52)
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
    let accessibilityIdentifier: (Item) -> String
    let select: (Item) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                Button { select(item) } label: {
                    HStack(spacing: 10) {
                        Text(item[keyPath: title]).font(.system(size: 16, weight: item[keyPath: isSystem] ? .medium : .regular))
                        Spacer()
                        Image(systemName: item[keyPath: isSystem] ? "lock.fill" : "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(KnowledgeVisualTokens.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: KnowledgeVisualTokens.rowHeight)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityIdentifier(item))
                if item.id != items.last?.id { Divider().padding(.leading, 16).overlay(KnowledgeVisualTokens.divider) }
            }
        }
        .frame(width: KnowledgeVisualTokens.groupWidth)
        .background(.white, in: RoundedRectangle(cornerRadius: KnowledgeVisualTokens.groupCornerRadius))
        .padding(.horizontal, KnowledgeVisualTokens.pageInset)
    }
}

private struct KnowledgeHomeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
