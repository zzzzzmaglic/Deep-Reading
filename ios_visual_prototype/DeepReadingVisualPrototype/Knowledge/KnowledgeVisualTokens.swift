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
}

enum KnowledgeHomeHeader: String {
    case collections
    case tags
}

enum KnowledgeHomeHeaderPolicy {
    static let minimumHitAreaHeight: CGFloat = 44

    static func toggleTarget(for header: KnowledgeHomeHeader) -> KnowledgeHomeHeader {
        header
    }
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
