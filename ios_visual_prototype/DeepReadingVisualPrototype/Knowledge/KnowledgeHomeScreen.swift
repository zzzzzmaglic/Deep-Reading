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
