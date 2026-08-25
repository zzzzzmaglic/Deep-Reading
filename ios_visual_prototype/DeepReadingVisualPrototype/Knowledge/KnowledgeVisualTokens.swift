import SwiftUI

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
    /// UnionTabView 1.2.0 defaults: two 86×58 items plus 4pt outer padding.
    static let tabBarWidth: CGFloat = 180
    static let tabBarHeight: CGFloat = 66
    static let tabBarItemWidth: CGFloat = 86
    static let tabBarItemHeight: CGFloat = 58
    static let tabBarLeadingInset: CGFloat = 20
    static let tabBarBottomInset: CGFloat = 30
    static let tabBarIconSize: CGFloat = 20
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
    static let usesVendoredUnionTabView = true
    static let vendoredSourceTag = "1.2.0"
    static let vendoredSourceRevision = "abf9afc364b315d1d058975c6ebbfabde6be06ea"
    static let usesNativeSegmentedControlSelection = true
    static let usesPrivateAPI = false
    static let usesSingleAnimationDriver = true
    static let usesSingleSynchronousSelectionBinding = true
    static let usesNativeTabViewContentHost = true
    static let usesBottomSafeAreaInsetHost = true
    static let usesOpacitySwitchedFullScreenLayers = false
    /// UnionTabView documents a bounce as an item-level effect. Our tab icons
    /// are exported assets rather than SF Symbols, so the equivalent native
    /// SwiftUI keyframe spring is applied to the complete selected item.
    static let usesNativeSelectionItemBounce = true
    static let selectionItemBouncePeakScale: CGFloat = 1.10
    static let selectedContentTintHex: UInt32 = 0x007AFF
    static let selectedContentTint = Color(hex: selectedContentTintHex)
    static let selectedGlassTint = Color.gray.opacity(0.15)
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
    static let collectionCardSpacing: CGFloat = 5
    static let tagAssetSpacing: CGFloat = 8
    static let collectionCardContentInset: CGFloat = 13
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
