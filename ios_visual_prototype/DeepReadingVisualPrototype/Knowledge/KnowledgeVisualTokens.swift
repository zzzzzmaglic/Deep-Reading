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
    static let tabBarWidth: CGFloat = 208
    static let tabBarHeight: CGFloat = 62
    static let tabBarItemWidth: CGFloat = 102
    static let tabBarLeadingInset: CGFloat = 20
    static let tabBarBottomInset: CGFloat = 30
    static let tabBarIconSize: CGFloat = 20
    static let knowledgeTabSelectedBackgroundOffset: CGFloat = -6
    static let knowledgeTabSelectedContentOffset: CGFloat = -4
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
    static let usesSinglePersistentSelectionSurface = true
    static let usesSingleAnimationDriver = true
    /// The outer bar remains the one Liquid Glass surface. Interaction on that
    /// surface makes iOS resample the material while the selection moves, which
    /// reads as a flash when its backdrop changes at the same time.
    static let containerUsesInteractiveGlass = false
    /// A moving Liquid Glass element inside another Liquid Glass element causes
    /// a second material resample. The selection is deliberately a solid,
    /// persistent capsule instead.
    static let selectionPillUsesLiquidGlass = false
    static let selectionPillUsesStableFill = true
    /// Commit the root-page change after the visible selection pill finishes
    /// its single motion. This keeps the glass backdrop stable during motion.
    static let selectionCommitDelayMilliseconds: UInt64 = 240
    static let selectedContentTintHex: UInt32 = 0x007AFF
    static let selectedContentTint = Color(hex: selectedContentTintHex)
    /// Preserves Figma's darker selected capsule without sampling the backdrop.
    static let selectedPillFill = Color(hex: 0xEDEDED)
}

enum KnowledgeHomeTitleCollapsePolicy {
    /// The enclosing content starts below the 59pt status area, so this maps
    /// to the Figma compact-title top coordinate of y=61.
    static let compactTitleTopInset: CGFloat = 2
    /// At this content offset the compact title begins sliding up from below
    /// the top bar. The large scroll title disappears at this same boundary.
    static let compactTitleRevealOffset: CGFloat = 35
    /// Initial large title baseline: 115...159pt. Once scrolled by 51pt, its
    /// entire 44pt text box is contained by the top edge (ending at 108pt).
    static let compactTitleFullyVisibleOffset: CGFloat = 51
    /// The compact title starts below its final baseline and is driven upward
    /// by the final 16pt of the content scroll, never by a fade animation.
    static let compactTitleSlideDistance: CGFloat = 18

    static func isCompactTitlePresented(for contentOffset: CGFloat) -> Bool {
        contentOffset >= compactTitleRevealOffset
    }

    static func compactTitleVerticalOffset(for contentOffset: CGFloat) -> CGFloat {
        let span = compactTitleFullyVisibleOffset - compactTitleRevealOffset
        guard span > 0 else { return 0 }
        let progress = min(max((contentOffset - compactTitleRevealOffset) / span, 0), 1)
        return compactTitleSlideDistance * (1 - progress)
    }

    static func largeTitleOpacity(for contentOffset: CGFloat) -> Double {
        isCompactTitlePresented(for: contentOffset) ? 0 : 1
    }
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
