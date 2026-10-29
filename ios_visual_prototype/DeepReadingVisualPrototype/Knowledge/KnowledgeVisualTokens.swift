import SwiftUI
import UIKit

enum KnowledgeVisualTokens {
    static let background = Color(hex: 0xF2F2F7)
    static let primaryText = Color(hex: 0x1D1D1F)
    static let secondaryText = Color(hex: 0x8E8E93)
    static let divider = Color(hex: 0xE5E5EA)
    static let groupWidth: CGFloat = 371
    static let groupCornerRadius: CGFloat = 18
    static let rowHeight: CGFloat = 47
    static let pageInset: CGFloat = 11
    static let titleSize: CGFloat = 34
    static let sectionTitleSize: CGFloat = 21
    static let progressiveEdgeHeight: CGFloat = 116
    static let cardHeight: CGFloat = 106
    static let cardCornerRadius: CGFloat = 15
    static let cardSpacing: CGFloat = 5
    static let coverWidth: CGFloat = 74
    static let coverHeight: CGFloat = 78
    /// Two equal items plus 4pt outer padding on each edge.
    static let tabBarWidth: CGFloat = 185
    static let tabBarHeight: CGFloat = 62
    static let tabBarItemWidth: CGFloat = 88.5
    static let tabBarItemHeight: CGFloat = 54
    static let tabBarLeadingInset: CGFloat = 20
    static let tabBarBottomInset: CGFloat = 20
    static let tabBarIconSize: CGFloat = 22
}

enum ReadingFeedLayout {
    static let sectionTitleWidth: CGFloat = 86
    static let sectionTitleHeight: CGFloat = 27
    static let dailyTitleTopInset: CGFloat = 9
    static let dailyTitleBottomSpacing: CGFloat = 12
    static let cardWidth: CGFloat = 371
    static let dailyCardHeight: CGFloat = 210
    static let cognitiveRoamingHeight: CGFloat = 200
    static let cardCornerRadius: CGFloat = 15
    static let coverWidth: CGFloat = 74
    static let coverHeight: CGFloat = 78
    static let coverCornerRadius: CGFloat = 12
    static let titleWidth: CGFloat = KnowledgeDetailLayout.collectionTitleTextWidth
    static let introductionWidth: CGFloat = 347
    static let introductionHeight: CGFloat = 82
    static let pageDotDiameter: CGFloat = 8
    static let pageDotSpacing: CGFloat = 8
    static let articleCount = 4
}

enum KnowledgeHomeHeader: String {
    case collections
    case tags
}

enum KnowledgeHomeHeaderPolicy {
    /// Figma 12 / 12b: the disclosure itself owns the 44×44 hit target.
    /// Keeping the title outside this button prevents a whole header row tap.
    static let disclosureHitArea: CGFloat = 44
    static let disclosureGlyphSize: CGFloat = 22
    static let titleToDisclosureOverlap: CGFloat = -11
    static let disclosureVisualOffsetX: CGFloat = 1
    static let hasFullRowTapTarget = false

    // Retained for existing callers that only need the target dimension.
    static let minimumHitAreaHeight = disclosureHitArea

    /// The compact state displays at most five rows, so its right-facing
    /// chevron means that more items can be expanded. A downward chevron
    /// means that the entire group is currently visible.
    static func disclosureRotationDegrees(isExpanded: Bool) -> Double {
        isExpanded ? 90 : 0
    }

    static func toggleTarget(for header: KnowledgeHomeHeader) -> KnowledgeHomeHeader {
        header
    }
}

enum KnowledgeTabBarPolicy {
    static let usesNativeLiquidGlass = true
    static let itemCount = 2
    static let hasMovingSelectionPill = true
    /// The formal bar now uses UIKit interactive Glass. The vendored source is
    /// retained only by the A/B diagnostic variants for comparison.
    static let usesVendoredUnionTabView = false
    static let retainsVendoredUnionTabViewForAB = true
    static let vendoredSourceTag = "1.2.0"
    static let vendoredSourceRevision = "abf9afc364b315d1d058975c6ebbfabde6be06ea"
    static let usesNativeSegmentedControlSelection = true
    static let usesUIKitInteractiveGlassSurface = true
    static let placesContentOverlayAboveUIKitSurface = true
    static let usesPrivateAPI = false
    static let usesSingleAnimationDriver = true
    static let usesSingleSynchronousSelectionBinding = true
    static let usesNativeTabViewContentHost = true
    static let usesBottomSafeAreaInsetHost = true
    static let usesOpacitySwitchedFullScreenLayers = false
    /// The selected item's icon and label live beside the glass and segmented
    /// control in UIKit, so their spring never crosses a SwiftUI hosting layer.
    static let usesNativeSelectionItemBounce = false
    static let usesUIKitSelectionItemBounce = true
    static let selectionItemBouncePeakScale: CGFloat = 1.20
    static let selectedContentTintHex: UInt32 = 0x007AFF
    static let selectedContentTint = Color(hex: selectedContentTintHex)
    static let selectedGlassTint = Color.gray.opacity(0.15)
}

/// The formal knowledge bar keeps its glass, selection indicator, icon/label
/// views, and selection spring in one UIKit rendering tree.
@available(iOS 26, *)
@MainActor
struct UIKitKnowledgeGlassTabBar: UIViewRepresentable {
    @Binding var selection: AppTab
    var accessibilityIdentifier: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIKitInteractiveGlassSegmentedTabBarView {
        let view = UIKitInteractiveGlassSegmentedTabBarView()
        view.accessibilityIdentifier = accessibilityIdentifier
        view.onSelectionChanged = { tab in
            context.coordinator.parent.selection = tab
        }
        view.attachNativeKnowledgeTabItems()
        view.apply(selection: selection, animated: false)
        return view
    }

    func updateUIView(_ view: UIKitInteractiveGlassSegmentedTabBarView, context: Context) {
        context.coordinator.parent = self
        view.accessibilityIdentifier = accessibilityIdentifier
        view.apply(selection: selection, animated: true)
    }

    @MainActor
    final class Coordinator {
        var parent: UIKitKnowledgeGlassTabBar

        init(parent: UIKitKnowledgeGlassTabBar) {
            self.parent = parent
        }
    }
}

/// The formal knowledge tab bar's UIKit substrate. UIKit owns the iOS 26
/// interactive glass and the native segmented selection indicator; SwiftUI
/// supplies the project's existing icon/label overlay above this surface.
@available(iOS 26, *)
@MainActor
struct UIKitInteractiveGlassSegmentedTabBar<Content: View>: UIViewRepresentable {
    @Binding var selection: AppTab
    var accessibilityIdentifier: String?
    private let content: (AppTab) -> Content

    init(
        selection: Binding<AppTab>,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping (AppTab) -> Content
    ) {
        _selection = selection
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIKitInteractiveGlassSegmentedTabBarView {
        let view = UIKitInteractiveGlassSegmentedTabBarView()
        view.accessibilityIdentifier = accessibilityIdentifier
        view.onSelectionChanged = { tab in
            context.coordinator.parent.selection = tab
        }
        let hostingController = UIHostingController(
            rootView: AnyView(
                UIKitInteractiveGlassTabContent(
                    selection: $selection,
                    content: { AnyView(content($0)) }
                )
            )
        )
        context.coordinator.hostingController = hostingController
        view.attachContentView(hostingController.view)
        view.apply(selection: selection, animated: false)
        return view
    }

    func updateUIView(_ view: UIKitInteractiveGlassSegmentedTabBarView, context: Context) {
        context.coordinator.parent = self
        view.accessibilityIdentifier = accessibilityIdentifier
        view.apply(selection: selection, animated: true)
    }

    @MainActor
    final class Coordinator {
        var parent: UIKitInteractiveGlassSegmentedTabBar
        var hostingController: UIHostingController<AnyView>?

        init(parent: UIKitInteractiveGlassSegmentedTabBar) {
            self.parent = parent
        }
    }
}

/// Keeps the project-provided icon/label content reactive to the same
/// selection binding while placing it inside UIKit's glass content view.
private struct UIKitInteractiveGlassTabContent: View {
    @Binding var selection: AppTab
    let content: (AppTab) -> AnyView

    var body: some View {
        content(selection)
            .allowsHitTesting(false)
            .background(Color.clear)
    }
}

@available(iOS 26, *)
@MainActor
final class UIKitInteractiveGlassSegmentedTabBarView: UIView {
    var onSelectionChanged: ((AppTab) -> Void)?

    private let tabs = AppTab.allCases
    private let glassView: UIVisualEffectView
    private let segmentedControl = UISegmentedControl(items: AppTab.allCases.map { _ in "" })
    private var currentSelection = AppTab.home
    private var nativeTabItems: [AppTab: UIKitKnowledgeTabItemView] = [:]
    private var selectionAtTouchStart = UISegmentedControl.noSegment

    override init(frame: CGRect) {
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        glassView = UIVisualEffectView(effect: effect)
        super.init(frame: frame)
        configureChrome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Two formal 86×58pt items, surrounded by the same 4pt inset as the
    /// previous SwiftUI GlassTabBar.
    override var intrinsicContentSize: CGSize {
        CGSize(
            width: KnowledgeVisualTokens.tabBarWidth,
            height: KnowledgeVisualTokens.tabBarHeight
        )
    }

    func apply(selection: AppTab, animated: Bool) {
        let selectionChanged = currentSelection != selection
        currentSelection = selection
        if selectionChanged {
            updateNativeTabItems(selection: selection, animated: animated)
        }

        let selectedIndex = tabs.firstIndex(of: selection) ?? 0
        guard segmentedControl.selectedSegmentIndex != selectedIndex else { return }

        if animated {
            segmentedControl.selectedSegmentIndex = selectedIndex
        } else {
            UIView.performWithoutAnimation {
                segmentedControl.selectedSegmentIndex = selectedIndex
                segmentedControl.layoutIfNeeded()
            }
        }
    }

    private func configureChrome() {
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.cornerConfiguration = .capsule()
        glassView.clipsToBounds = true
        addSubview(glassView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = tabs.firstIndex(of: currentSelection) ?? 0
        segmentedControl.selectedSegmentTintColor = UIColor(KnowledgeTabBarPolicy.selectedGlassTint)
        segmentedControl.backgroundColor = .clear
        segmentedControl.addTarget(self, action: #selector(segmentTouchBegan(_:)), for: .touchDown)
        segmentedControl.addTarget(self, action: #selector(segmentTouchEnded(_:)), for: .touchUpInside)
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        glassView.contentView.addSubview(segmentedControl)

        // UISegmentedControl is used only for native selection geometry and
        // touch handling. SwiftUI renders the visible project icon and label.
        DispatchQueue.main.async {
            for subview in self.segmentedControl.subviews {
                if subview is UIImageView, subview != self.segmentedControl.subviews.last {
                    subview.alpha = 0
                }
            }
        }

        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 4),
            segmentedControl.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -4),
            segmentedControl.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 4),
            segmentedControl.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -4)
        ])
    }

    /// UIKit may reorder its selected-segment render layer while interacting.
    /// Hosting the app's pre-existing SwiftUI icon/label content after the
    /// segment control makes it a stable sibling above that layer.
    func attachContentView(_ contentView: UIView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        contentView.isOpaque = false
        contentView.isUserInteractionEnabled = false
        glassView.contentView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 4),
            contentView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -4),
            contentView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 4),
            contentView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -4)
        ])
    }

    /// The production icon and label layer. It intentionally does not use a
    /// UIHostingController: selection tint and the bounce are both UIKit state.
    func attachNativeKnowledgeTabItems() {
        guard nativeTabItems.isEmpty else { return }

        let itemViews = tabs.map { tab in
            let itemView = UIKitKnowledgeTabItemView(tab: tab)
            nativeTabItems[tab] = itemView
            return itemView
        }
        let stackView = UIStackView(arrangedSubviews: itemViews)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.isUserInteractionEnabled = false
        glassView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -4)
        ])

        updateNativeTabItems(selection: currentSelection, animated: false)
    }

    private func updateNativeTabItems(selection: AppTab, animated: Bool) {
        for tab in tabs {
            nativeTabItems[tab]?.setSelected(
                tab == selection,
                animated: animated && tab == selection
            )
        }
    }

    private func replayBounceForReselectedTab(at selectedIndex: Int) {
        guard selectedIndex >= 0, selectedIndex < tabs.count else { return }
        let tab = tabs[selectedIndex]
        guard tab == currentSelection else { return }
        nativeTabItems[tab]?.replayBounce()
    }

    @objc private func segmentTouchBegan(_ control: UISegmentedControl) {
        selectionAtTouchStart = control.selectedSegmentIndex
    }

    @objc private func segmentTouchEnded(_ control: UISegmentedControl) {
        let selectionBeforeTouch = selectionAtTouchStart
        selectionAtTouchStart = UISegmentedControl.noSegment

        // Resolve after UIKit has delivered any `.valueChanged` action for
        // this touch. A new selection must animate only once through that
        // normal path; a repeated selection gets its own feedback here.
        DispatchQueue.main.async { [weak self, weak control] in
            guard let self, let control,
                  control.selectedSegmentIndex == selectionBeforeTouch else { return }
            self.replayBounceForReselectedTab(at: control.selectedSegmentIndex)
        }
    }

    @objc private func segmentChanged(_ control: UISegmentedControl) {
        guard control.selectedSegmentIndex >= 0,
              control.selectedSegmentIndex < tabs.count else { return }
        let tab = tabs[control.selectedSegmentIndex]
        guard currentSelection != tab else { return }
        currentSelection = tab
        updateNativeTabItems(selection: tab, animated: true)
        onSelectionChanged?(tab)
    }
}

@available(iOS 26, *)
@MainActor
private final class UIKitKnowledgeTabItemView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(tab: AppTab) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityIdentifier = "knowledge-tab-\(tab.rawValue)"
        accessibilityLabel = tab.rawValue

        iconView.translatesAutoresizingMaskIntoConstraints = false
        let symbolName = tab == .home ? "house.fill" : "tray.fill"
        let symbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 22,
            weight: .medium,
            scale: .medium
        )
        iconView.image = UIImage(
            systemName: symbolName,
            withConfiguration: symbolConfiguration
        )?.withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.attributedText = NSAttributedString(
            string: tab.rawValue,
            attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .kern: -0.1
            ]
        )
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1

        let contentStack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = 2
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: KnowledgeVisualTokens.tabBarIconSize),
            iconView.heightAnchor.constraint(equalToConstant: KnowledgeVisualTokens.tabBarIconSize),
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ isSelected: Bool, animated: Bool) {
        let tint = isSelected
            ? UIColor(red: 0, green: 122 / 255, blue: 1, alpha: 1)
            : UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1)
        iconView.tintColor = tint
        titleLabel.textColor = tint

        guard animated else {
            layer.removeAllAnimations()
            transform = .identity
            return
        }
        animateSelectionBounce()
    }

    private func animateSelectionBounce() {
        layer.removeAllAnimations()
        transform = .identity

        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            usingSpringWithDamping: 0.62,
            initialSpringVelocity: 0.55,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(
                scaleX: KnowledgeTabBarPolicy.selectionItemBouncePeakScale,
                y: KnowledgeTabBarPolicy.selectionItemBouncePeakScale
            )
        } completion: { [weak self] completed in
            guard completed, let self else { return }
            UIView.animate(
                withDuration: 0.24,
                delay: 0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.35,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.transform = .identity
            }
        }
    }

    func replayBounce() {
        animateSelectionBounce()
    }
}

enum KnowledgeHomeNavigationBarPolicy {
    /// Match the Files app's native title collapse: the NavigationStack owns
    /// the large-to-inline transition and the corresponding scroll-edge glass.
    static let usesSystemLargeTitle = true
    static let usesSystemScrollEdgeMaterial = true
    static let usesCustomScrollTitleTracking = false
    static let usesCustomTopProgressiveEdge = false
}

enum KnowledgeDetailLayout {
    /// Matches the already accepted current-article summary list, leaving the
    /// 116pt chrome clear and beginning content at y=123.
    static let contentTopInset: CGFloat = 123
    /// Figma 13 starts the collection's first article card at y=116.
    static let collectionContentTopInset: CGFloat = 116
    static let usesFullScreenCoordinateSpace = true
    static let collectionCardSpacing: CGFloat = 5
    static let tagAssetSpacing: CGFloat = 8
    static let collectionCardContentInset: CGFloat = 13
    static let collectionCoverCornerRadius: CGFloat = 12
    /// The title and metadata share this fixed trailing edge.
    static let collectionTitleTextWidth: CGFloat = 224
    static let collectionMetadataGroupSpacing: CGFloat = 14
    static let tagChromeTrailingInset: CGFloat = 23
}

enum KnowledgeCoverAssetName {
    static let seedArticleAssetNames = ["KnowledgeCover1", "KnowledgeCover2", "KnowledgeCover3"]
    private static let exportedAssetNames = Set((1...6).map { "KnowledgeCover\($0)" })

    static func isExported(_ name: String) -> Bool {
        exportedAssetNames.contains(name)
    }
}

enum CollectionDetailChromeLayer: Equatable {
    case progressiveEdge
    case chrome
}

enum CollectionDetailScreenPolicy {
    static let topLayerOrder: [CollectionDetailChromeLayer] = [.progressiveEdge, .chrome]

    static func attachesSelectionGesture(isLockedCollection: Bool) -> Bool {
        !isLockedCollection
    }
}

enum KnowledgeDetailNavigationTitlePolicy {
    static func title(initialTitle: String, loadedTitle: String?) -> String {
        guard let loadedTitle, !loadedTitle.isEmpty else { return initialTitle }
        return loadedTitle
    }
}
