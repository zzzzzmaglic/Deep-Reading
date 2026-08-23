import Combine
import Foundation

enum KnowledgeHomeFailure: LocalizedError, Equatable {
    case loadFailed

    var errorDescription: String? { "知识库未能加载，请重试。" }
}

@MainActor
final class KnowledgeHomeCoordinator: ObservableObject {
    @Published private(set) var snapshot: KnowledgeHomeSnapshot?
    @Published private(set) var collectionsExpanded = false
    @Published private(set) var tagsExpanded = false
    @Published private(set) var failure: KnowledgeHomeFailure?

    private let repository: any KnowledgeBaseRepository

    init(repository: any KnowledgeBaseRepository) {
        self.repository = repository
    }

    var visibleCollections: [KnowledgeCollection] {
        visible(sortedCollections, expanded: collectionsExpanded)
    }

    var visibleTags: [Tag] {
        visible(sortedTags, expanded: tagsExpanded)
    }

    func load() async {
        do {
            snapshot = try await repository.readHome()
            failure = nil
        } catch {
            failure = .loadFailed
        }
    }

    func toggleCollections() { collectionsExpanded.toggle() }
    func toggleTags() { tagsExpanded.toggle() }

    private var sortedCollections: [KnowledgeCollection] {
        (snapshot?.collections ?? []).sorted { lhs, rhs in
            if lhs.isSystem != rhs.isSystem { return lhs.isSystem }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var sortedTags: [Tag] {
        (snapshot?.tags ?? []).sorted { lhs, rhs in
            if lhs.isSystem != rhs.isSystem { return lhs.isSystem }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func visible<Item>(_ values: [Item], expanded: Bool) -> [Item] {
        expanded ? values : Array(values.prefix(5))
    }
}
