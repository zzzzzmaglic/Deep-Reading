import SwiftUI

/// A non-product launch mode that isolates the tab-bar structure while keeping
/// both variants on the same iPhone 16 / iOS 26 simulator.
enum TabBarABVariant: String, Equatable {
    case upstream
    case helper
    case segmented
    case uikitInteractive

    static func from(arguments: [String]) -> Self? {
        if arguments.contains("-tab-bar-ab-upstream") { return .upstream }
        if arguments.contains("-tab-bar-ab-helper") { return .helper }
        if arguments.contains("-tab-bar-ab-segmented") { return .segmented }
        if arguments.contains("-tab-bar-ab-uikit-interactive") { return .uikitInteractive }
        return nil
    }
}

#if DEBUG
@available(iOS 26, *)
struct TabBarABExperimentRoot: View {
    let variant: TabBarABVariant

    @State private var selection: AppTab = .home
    @State private var helperBottomInset: CGFloat = 0

    var body: some View {
        Group {
            switch variant {
            case .upstream:
                upstreamStructure
            case .helper:
                helperStructure
            case .segmented:
                segmentedPickerStructure
            case .uikitInteractive:
                uikitInteractiveStructure
            }
        }
        .accessibilityIdentifier("tab-bar-ab-\(variant.rawValue)")
    }

    /// The upstream root pattern: UnionTabView plus unionTab markers.
    private var upstreamStructure: some View {
        UnionTabView(selection: $selection, tabs: AppTab.allCases) {
            experimentPage(for: .home).unionTab(AppTab.home)
            experimentPage(for: .knowledge).unionTab(AppTab.knowledge)
        } item: { tab, isSelected in
            tabItem(tab, isSelected: isSelected)
        }
    }

    /// The project pattern: a small, left-bottom GlassTabBar helper.
    private var helperStructure: some View {
        TabView(selection: $selection) {
            experimentPage(for: .home)
                .unionTab(AppTab.home)
            experimentPage(for: .knowledge)
                .unionTab(AppTab.knowledge)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassTabBar(
                activeTab: $selection,
                activeTint: .blue,
                barTint: .gray.opacity(0.15),
                itemWidth: KnowledgeVisualTokens.tabBarItemWidth,
                itemHeight: KnowledgeVisualTokens.tabBarItemHeight
            ) { tab, isSelected in
                tabItem(tab, isSelected: isSelected)
            }
            .frame(width: KnowledgeVisualTokens.tabBarWidth, height: KnowledgeVisualTokens.tabBarHeight)
            .ignoresSafeArea()
            .padding(.leading, KnowledgeVisualTokens.tabBarLeadingInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(
                .bottom,
                -helperBottomInset + KnowledgeVisualTokens.tabBarBottomInset
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.safeAreaInsets.bottom
            } action: { value in
                helperBottomInset = value
            }
        }
    }

    /// A single standard SwiftUI control. Unlike A and B, this deliberately has
    /// no custom glass wrapper and no bridged UIKit control supplied by us.
    private var segmentedPickerStructure: some View {
        experimentPage(for: selection)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Picker("诊断页面", selection: $selection) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.symbol)
                            .tag(tab)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .accessibilityIdentifier("tab-bar-ab-segmented-picker")
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
    }

    /// D keeps the production bar's left-bottom geometry, but moves only the
    /// glass shell to UIKit. Its public UIGlassEffect explicitly opts in to
    /// native interactive press behavior, while UISegmentedControl owns the
    /// selection indicator and touch tracking.
    @available(iOS 26, *)
    private var uikitInteractiveStructure: some View {
        TabView(selection: $selection) {
            experimentPage(for: .home)
                .unionTab(AppTab.home)
            experimentPage(for: .knowledge)
                .unionTab(AppTab.knowledge)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            UIKitInteractiveGlassSegmentedTabBar(
                selection: $selection,
                accessibilityIdentifier: "tab-bar-ab-uikit-interactive-control"
            ) { currentSelection in
                HStack(spacing: 0) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        tabItem(tab, isSelected: currentSelection == tab)
                            .frame(
                                width: KnowledgeVisualTokens.tabBarItemWidth,
                                height: KnowledgeVisualTokens.tabBarItemHeight
                            )
                    }
                }
            }
            .frame(width: KnowledgeVisualTokens.tabBarWidth, height: KnowledgeVisualTokens.tabBarHeight)
                .ignoresSafeArea()
                .padding(.leading, KnowledgeVisualTokens.tabBarLeadingInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(
                    .bottom,
                    -helperBottomInset + KnowledgeVisualTokens.tabBarBottomInset
                )
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.safeAreaInsets.bottom
                } action: { value in
                    helperBottomInset = value
                }
        }
    }

    private func experimentPage(for tab: AppTab) -> some View {
        ZStack {
            KnowledgeVisualTokens.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(experimentTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(tab.rawValue)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(KnowledgeVisualTokens.primaryText)
            }
        }
    }

    private var experimentTitle: String {
        switch variant {
        case .upstream:
            "A · 完整上游结构"
        case .helper:
            "B · 左下辅助组件"
        case .segmented:
            "C · 原生 Segmented Picker"
        case .uikitInteractive:
            "D · UIKit interactive + UISegmentedControl"
        }
    }

    private func tabItem(_ tab: AppTab, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? tab.symbol : tab.actionSymbol)
                .font(.title3)
            Text(tab.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(isSelected ? Color.blue : Color.secondary)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
