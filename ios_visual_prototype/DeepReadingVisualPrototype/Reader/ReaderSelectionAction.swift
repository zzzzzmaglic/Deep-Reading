import Foundation

enum ReaderSelectionAction: Sendable, Equatable {
    case highlight
    case removeHighlight
    case openAssetCard
    case manageTags
    case copy
    case explainWithAI
}
