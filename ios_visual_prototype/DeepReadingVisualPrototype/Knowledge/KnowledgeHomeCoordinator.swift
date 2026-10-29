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

    var tagAssetCounts: [UUID: Int] {
        snapshot?.tagAssetCounts ?? [:]
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

enum ReadingFeedFailure: LocalizedError, Equatable {
    case loadFailed

    var errorDescription: String? { "每日推文未能加载，请重试。" }
}

enum ReadingFeedArticleIntroduction {
    static func text(for articleTitle: String) -> String {
        introductions[articleTitle] ?? ""
    }

    private static let introductions: [String: String] = [
        "1600-2100年的公司简史":
            "四百年风云，公司从海上劫掠者蜕变为时间商人，如今正撞上注意力的天花板。翻过这页，你会明白喧嚣的尽头，只剩个体才是真实的尺度。它照见你此刻的疲惫——为什么越努力越焦虑，为什么大组织越来越笨重，为什么那些离开工位去流浪...",
        "达尔文是个“懒虫”，你也应该如此":
            "达尔文每天只专注四小时，其余时间散步、小睡、发呆，却写出物种起源。你还在为没加班到深夜自责吗？顶尖小提琴手同样每天只练四小时，还比普通学生多睡一小时。休息不是偷懒，而是创造力的另一半。",
        "为你的大脑收集训练数据":
            "你每天刷到的内容，正在悄悄训练你的大脑。垃圾进，垃圾出。克瑙斯高写了十年烂泥，直到遇见普鲁斯特才找到自己的情感天赋。问题不在你不够努力，而在你喂给大脑的样本太差，更没认清自己真正擅长什么。",
        "当我们在聊情商时，到底在聊什么？":
            "情商常被误读为会说话、会来事。真正拉开差距的，是自我认知、情绪调节与内驱力。研究显示，职位越高，情商对成败的影响越明显。你越想靠技巧赢得好感，越容易忽略最该读懂的人——自己。",
    ]
}

@MainActor
final class ReadingFeedCoordinator: ObservableObject {
    @Published private(set) var articles: [KnowledgeArticlePreview] = []
    @Published var selectedPage = 0
    @Published private(set) var failure: ReadingFeedFailure?

    private let repository: any KnowledgeBaseRepository

    init(repository: any KnowledgeBaseRepository) {
        self.repository = repository
    }

    func load() async {
        do {
            let home = try await repository.readHome()
            guard let archive = home.collections.first(where: { $0.isSystem }) else {
                throw ReadingFeedFailure.loadFailed
            }
            articles = try await repository.readCollectionArticles(collectionID: archive.id)
            selectedPage = min(selectedPage, max(articles.count - 1, 0))
            failure = nil
        } catch {
            articles = []
            selectedPage = 0
            failure = .loadFailed
        }
    }
}
