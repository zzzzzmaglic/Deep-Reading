//
//  UnionTabView.swift
//  UnionTabView
//
//  Source: union-tab-view 7f901757c7b6e4cca62cf637f8e005ea366b4c7d
//  Retained in its upstream structure for the in-app A/B diagnostic only.
//

import SwiftUI

/// An adaptive tab view that renders a Liquid Glass floating tab bar on iOS 26+ with fully custom tab item views.
///
/// On iOS 26, Apple's standard `TabView` only supports system-provided tab items. `UnionTabView` gives you
/// the beautiful floating glass effect while allowing **any custom SwiftUI view** for each tab—icons, labels,
/// badges, animations, whatever you want.
///
/// On iOS 17-25, falls back to a clean custom tab bar with the same API.
public enum UnionTabBarMetrics {
    /// Height of the row of tab items when the host does not specify one.
    public static let contentHeight: CGFloat = 58
    /// Inset between that row and the edge of the glass capsule.
    public static let padding: CGFloat = 14.0 / 3.0
    /// Full height of the bar at rest, which is what a tab must reserve.
    public static var height: CGFloat { contentHeight + (padding * 2) }

    /// Full height of a bar built with a specific item-row height.
    public static func height(contentHeight: CGFloat) -> CGFloat {
        contentHeight + (padding * 2)
    }

    /// Distance the bar rests above the physical bottom of the screen.
    public static let restingBottomInset: CGFloat = 22
}

public struct UnionTabView<Tab: Hashable, Content: View, TabItemContent: View>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let minimizeProgress: Double
    let hideOffset: CGFloat
    let contentHeight: CGFloat
    let glassTint: Color?
    let minimizeAnimation: Animation?
    let isActionTab: (Tab) -> Bool
    let onActionTab: ((Tab) -> Void)?
    let onReselect: ((Tab) -> Void)?
    let content: Content
    let tabItemView: (Tab, Bool) -> TabItemContent

    public init(
        selection: Binding<Tab>,
        tabs: [Tab],
        minimizeProgress: Double = 0,
        hideOffset: CGFloat = 0,
        contentHeight: CGFloat = UnionTabBarMetrics.contentHeight,
        glassTint: Color? = nil,
        minimizeAnimation: Animation? = .spring(duration: 0.3),
        isActionTab: @escaping (Tab) -> Bool = { _ in false },
        onActionTab: ((Tab) -> Void)? = nil,
        onReselect: ((Tab) -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder item: @escaping (Tab, Bool) -> TabItemContent
    ) {
        self._selection = selection
        self.tabs = tabs
        self.minimizeProgress = minimizeProgress
        self.hideOffset = hideOffset
        self.contentHeight = contentHeight
        self.glassTint = glassTint
        self.minimizeAnimation = minimizeAnimation
        self.isActionTab = isActionTab
        self.onActionTab = onActionTab
        self.onReselect = onReselect
        self.content = content()
        self.tabItemView = item
    }

    private var minimizeScale: CGFloat {
        let clamped = min(max(minimizeProgress, 0), 1)
        return 1 - ((1 - 152.0 / 180.0) * clamped)
    }

    private var barHeight: CGFloat { contentHeight }

    public var body: some View {
        if #available(iOS 26, *) {
            iOS26Body
        } else {
            legacyBody
        }
    }

    @available(iOS 26, *)
    private var iOS26Body: some View {
        TabView(selection: $selection) {
            content
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                let gap = UIScreen.main.bounds.height - proxy.frame(in: .global).maxY
                glassTabBar
                    .padding(.horizontal, 22)
                    .padding(.bottom, UnionTabBarMetrics.restingBottomInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: gap)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var selectedIndex: Int {
        tabs.firstIndex(of: selection) ?? 0
    }

    @available(iOS 26, *)
    private var barGlass: Glass {
        let base: Glass = glassTint.map { .regular.tint($0) } ?? .regular
        return base.interactive()
    }

    @available(iOS 26, *)
    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                tabItemView(tab, selectedIndex == index)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: CGFloat(tabs.count) * 86)
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .background {
            GeometryReader { geometry in
                InteractiveSegmentedControl(
                    size: geometry.size,
                    barTint: .gray.opacity(0.15),
                    selectedIndex: Binding(
                        get: { selectedIndex },
                        set: { newIndex in
                            if newIndex < tabs.count {
                                selection = tabs[newIndex]
                            }
                        }
                    ),
                    itemCount: tabs.count,
                    actionIndices: Set(tabs.indices.filter { isActionTab(tabs[$0]) }),
                    canSelect: { index in
                        index < tabs.count && !isActionTab(tabs[index])
                    },
                    onRejectedTap: { index in
                        if index < tabs.count {
                            onActionTab?(tabs[index])
                        }
                    },
                    onReselect: { index in
                        if index < tabs.count {
                            onReselect?(tabs[index])
                        }
                    }
                )
            }
        }
        .background {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { _, tab in
                    if isActionTab(tab) {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { onActionTab?(tab) }
                    } else {
                        Color.clear
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(UnionTabBarMetrics.padding)
        .glassEffect(barGlass, in: .capsule)
        .scaleEffect(minimizeScale, anchor: .center)
        .animation(minimizeAnimation, value: minimizeProgress)
        .offset(y: hideOffset)
        .animation(minimizeAnimation, value: hideOffset)
    }

    private var legacyBody: some View {
        TabView(selection: $selection) {
            content
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                let gap = UIScreen.main.bounds.height - proxy.frame(in: .global).maxY
                legacyTabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: gap)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var legacyTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                tabItemView(tab, selectedIndex == index)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
            }
        }
        .frame(maxWidth: CGFloat(tabs.count) * 86)
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .padding(4)
        .offset(y: hideOffset)
        .animation(minimizeAnimation, value: hideOffset)
    }
}

final class DeadZoneSegmentedControl: UISegmentedControl {
    var deadIndices: Set<Int> = []

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard numberOfSegments > 0, bounds.width > 0 else {
            return super.hitTest(point, with: event)
        }
        let segmentWidth = bounds.width / CGFloat(numberOfSegments)
        let index = min(numberOfSegments - 1, max(0, Int(point.x / segmentWidth)))
        if deadIndices.contains(index) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

@MainActor
struct InteractiveSegmentedControl: UIViewRepresentable {
    var size: CGSize
    var barTint: Color
    @Binding var selectedIndex: Int
    var itemCount: Int
    var actionIndices: Set<Int> = []
    var canSelect: (Int) -> Bool = { _ in true }
    var onRejectedTap: ((Int) -> Void)? = nil
    var onReselect: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let items = (0..<itemCount).map { _ in "" }
        let control = DeadZoneSegmentedControl(items: items)
        control.deadIndices = actionIndices
        control.selectedSegmentIndex = selectedIndex

        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }

        control.selectedSegmentTintColor = UIColor(barTint)
        control.backgroundColor = .clear
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.segmentChanged(_:)),
            for: .valueChanged
        )

        let reselect = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        reselect.cancelsTouchesInView = false
        control.addGestureRecognizer(reselect)

        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        (uiView as? DeadZoneSegmentedControl)?.deadIndices = actionIndices
        if uiView.selectedSegmentIndex != selectedIndex {
            uiView.selectedSegmentIndex = selectedIndex
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UISegmentedControl,
        context: Context
    ) -> CGSize? {
        size
    }

    class Coordinator: NSObject {
        var parent: InteractiveSegmentedControl

        init(parent: InteractiveSegmentedControl) {
            self.parent = parent
        }

        @MainActor @objc func segmentChanged(_ control: UISegmentedControl) {
            let index = control.selectedSegmentIndex
            guard parent.canSelect(index) else {
                UIView.performWithoutAnimation {
                    control.selectedSegmentIndex = parent.selectedIndex
                    control.layoutIfNeeded()
                }
                parent.onRejectedTap?(index)
                return
            }
            guard index != parent.selectedIndex else { return }
            parent.selectedIndex = index
        }

        @MainActor @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let control = gesture.view as? UISegmentedControl,
                  control.numberOfSegments > 0 else { return }

            let segmentWidth = control.bounds.width / CGFloat(control.numberOfSegments)
            guard segmentWidth > 0 else { return }

            let location = gesture.location(in: control)
            let index = min(
                control.numberOfSegments - 1,
                max(0, Int(location.x / segmentWidth))
            )

            guard parent.canSelect(index), index == parent.selectedIndex else { return }
            parent.onReselect?(index)
        }
    }
}

public extension View {
    @ViewBuilder
    func unionTab<Tab: Hashable>(_ tab: Tab) -> some View {
        if #available(iOS 26, *) {
            self
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(tab)
        } else {
            self.tag(tab)
        }
    }
}
