# Native Task 10 Knowledge Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在原生 SwiftUI App 中交付 Task 10 的真实 Supabase 知识库浏览、范围内集合/标签资产操作，以及与阅读器和资产卡片的一致导航。

**Architecture:** 保持现有 `ArticleRepository` 和 `ReadingAssetRepository` 的职责，新增只负责集合及其可见文章的 `KnowledgeBaseRepository`。普通集合的移除以 owner-scoped exclusion 隐藏当前用户的全局 seed 归属；标签资产操作通过原子 RPC 处理。知识库根入口使用原生 iOS 26 `TabView`，知识库 Tab 自己持有 `NavigationStack`，由其栈保留详情页和阅读器返回上下文。

**Tech Stack:** Swift 5、SwiftUI、UIKit text views（已有资产卡片）、iOS 26、Supabase Swift、PostgreSQL/PLpgSQL、pgTAP、XCTest/XCUITest、iPhone 16 iOS Simulator。

**Spec:** `docs/superpowers/specs/2026-08-23-native-task10-knowledge-base-design.md`

## Global Constraints

- Task 10 是单一产品任务；本计划仅按 `10.1–10.4` 划分可独立审核的实施步骤。
- 保持原生 SwiftUI，不改回 Flutter；不接入 Task 11 AI、阅读流、Appetize 或发布。
- 真实数据只来自当前 `SupabaseClient`；不在客户端硬编码知识库条目、集合、标签或资产。
- 集合 seed 关系为全局只读；普通集合“移除”只创建当前 owner 的 exclusion，绝不删除全局关系或文章。
- “往期推文”是锁定集合，不能多选或移除；“摘录与思考”是每位用户自动拥有且不可取消选中的系统标签。
- 普通标签移除资产—标签关系；系统标签删除资产本身，均采用后端原子批量 RPC。
- 知识库 Tab 默认选中；“首页”仅作明确未实现的阅读流占位，不实现阅读流内容。
- 使用 iPhone 16 / iOS 26.5 为验收基准；Tab Bar 使用原生 `TabView`，不把 Figma Tab Bar 导出成图片。
- Figma 12–18 是视觉事实来源。仅在没有对应 SF Symbol 时，导出单个图标/封面到原型自己的 Asset Catalog。
- 不输出、提交或写入 service-role、JWT secret、DeepSeek 或其他服务端密钥；`Debug.xcconfig` 保持未跟踪。
- 不触碰本机运行时目录 `supabase/.branches/`、`supabase/.temp/`。

---

## Locked file structure

| 路径 | 责任 |
| --- | --- |
| `supabase/migrations/202608230001_task10_knowledge_base.sql` | 集合展示字段、锁定集合、owner exclusions、三个批量 RPC、RLS 与 grants |
| `supabase/seed.sql` | 为 seed 文章和集合写入确定的知识库展示元数据及足够的首页/集合数据 |
| `supabase/tests/008_task10_knowledge_base.test.sql` | pgTAP：owner 隔离、锁定集合拒绝、普通标签解除关联、系统标签原子删除 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Domain/Knowledge.swift` | `KnowledgeCollection`、`KnowledgeArticlePreview`、`KnowledgeHomeSnapshot` 等纯领域值 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Domain/RepositoryProtocols.swift` | `KnowledgeBaseRepository` 协议，以及资产批量操作协议方法 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseKnowledgeBaseRepository.swift` | 集合/预览读取与集合 exclusion RPC 的 Supabase 实现 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseReadingAssetRepository.swift` | 普通标签解除关联、系统标签原子删除 RPC 的实现 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeHomeCoordinator.swift` | 首页加载、独立折叠状态、失败重试 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeHomeScreen.swift` | Figma 12/12a–d 首页与原生滚动/折叠视觉 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/CollectionDetailCoordinator.swift` | 集合文章、多选、owner-scoped 移除和单飞状态 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/CollectionDetailScreen.swift` | Figma 13/14 集合详情卡片与移除操作层 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Assets/ReadingAssetListRow.swift` | 从汇总页抽取的可复用阅读资产条目；标签详情与汇总页共享 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/TagDetailCoordinator.swift` | 标签资产、普通移除/系统删除、独立笔记草稿与失败重试 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/TagDetailScreen.swift` | Figma 15–18 标签详情、资产卡片覆盖层与来源锚点导航 |
| `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeVisualTokens.swift` | 12–18 的集中布局/颜色/文字 token；复用已有 116 pt 渐进虚化 |
| `ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift` | `AppRuntime` 依赖注入、根 `TabView`、知识库导航栈和阅读器返回 |
| `ios_visual_prototype/DeepReadingVisualPrototypeTests/KnowledgeBaseRepositoryTests.swift` | 远端行解码、RPC 参数与 owner exclusion 单元测试 |
| `ios_visual_prototype/DeepReadingVisualPrototypeTests/KnowledgeHomeCoordinatorTests.swift` | 首页折叠和固定排序测试 |
| `ios_visual_prototype/DeepReadingVisualPrototypeTests/CollectionDetailCoordinatorTests.swift` | 集合选择、锁定保护、单飞移除测试 |
| `ios_visual_prototype/DeepReadingVisualPrototypeTests/TagDetailCoordinatorTests.swift` | 标签排序、两类批量操作、卡片草稿和锚点 route 测试 |
| `ios_visual_prototype/DeepReadingVisualPrototypeUITests/KnowledgeBaseFlowUITests.swift` | 默认知识库、详情返回、资产卡片、锚点阅读器返回的 UI 流程 |
| `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj` | 把新增 Swift/XCTest/XCUITest 文件放入正确 target |

`Article` 不增加知识库专用展示字段，避免让阅读器内容模型承担列表职责；`KnowledgeArticlePreview` 从 `articles` 的新增展示列单独解码。现有 `ReadingAssetCard`、`AssetDraftController`、`ReaderScreen`、`ReaderTopProgressiveBlur` 和 `GlassIconControl` 是复用点，不创建第二套资产编辑器、渐进虚化或玻璃控件。

---

### Task 1 (Task 10.1): 数据库安全契约与原生数据层

**Files:**
- Create: `supabase/migrations/202608230001_task10_knowledge_base.sql`
- Modify: `supabase/seed.sql`
- Create: `supabase/tests/008_task10_knowledge_base.test.sql`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Domain/Knowledge.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Domain/RepositoryProtocols.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseKnowledgeBaseRepository.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseReadingAssetRepository.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/KnowledgeBaseRepositoryTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototypeTests/Fakes/FakeRepositories.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj`

**Consumes:** 已有 `articles`、`collections`、`article_collections`、`tags`、`asset_tags`、`reading_assets`、系统标签触发器与 `SupabaseReadingAssetRemote`。

**Produces:**

```swift
struct KnowledgeCollection: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let isSystem: Bool
    let visibleArticleCount: Int
}

struct KnowledgeHomeSnapshot: Sendable, Equatable {
    let collections: [KnowledgeCollection]
    let tags: [Tag]
}

struct KnowledgeArticlePreview: Sendable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let sourceName: String
    let coverAssetName: String
    let cognitiveDimension: String
    let publishedAt: Date
    let readingAssetCount: Int
}

protocol KnowledgeBaseRepository: Sendable {
    func readHome() async throws -> KnowledgeHomeSnapshot
    func readCollection(id: UUID) async throws -> KnowledgeCollection
    func readCollectionArticles(collectionID: UUID) async throws -> [KnowledgeArticlePreview]
    func readArticleTitles(ids: Set<UUID>) async throws -> [UUID: String]
    func removeArticlesFromCollection(collectionID: UUID, articleIDs: [UUID]) async throws
}

protocol ReadingAssetRepository: Sendable {
    // Retain every existing Task 6–9 requirement, then add:
    func removeAssetsFromTag(tagID: UUID, assetIDs: [UUID]) async throws
    func deleteReadingAssets(ids: [UUID]) async throws
}
```

- [ ] **Step 1: 写 pgTAP 与 Swift 红灯测试**

创建 `008_task10_knowledge_base.test.sql`。在两个 `auth.users` 测试 owner 下：

```sql
select throws_ok(
  $$select public.remove_articles_from_collection(
      '30000000-0000-0000-0000-000000000001'::uuid,
      array['10000000-0000-0000-0000-000000000001'::uuid]
  )$$,
  '42501',
  'locked collections cannot be changed'
);

select lives_ok(
  $$select public.remove_articles_from_collection(
      current_setting('test.normal_collection_id')::uuid,
      array[current_setting('test.article_id')::uuid]
  )$$,
  'normal collection removal records an owner-scoped exclusion'
);
select is(
  (select count(*) from public.collection_article_exclusions
    where owner_id = current_setting('test.owner_one')::uuid),
  1::bigint,
  'only the current owner receives the exclusion'
);
```

同一文件还必须断言：普通标签 RPC 只删除当前 tag 的 `asset_tags` 行；系统标签 `delete_reading_assets(uuid[])` 在请求数组包含一个不属于当前 owner 的资产时整体抛 `42501`，且一个合法资产也没有被删除。

在 `KnowledgeBaseRepositoryTests.swift` 新增以下失败用例与 fake remote：

```swift
func testReadCollectionArticlesExcludesOnlyCurrentOwnersHiddenRows() async throws {
    let repository = SupabaseKnowledgeBaseRepository(remote: remote)
    let articles = try await repository.readCollectionArticles(collectionID: collectionID)
    XCTAssertEqual(articles.map(\.id), [visibleArticleID])
}

func testRemoveArticlesUsesTheAtomicCollectionRPC() async throws {
    try await repository.removeArticlesFromCollection(collectionID: collectionID, articleIDs: [articleID])
    XCTAssertEqual(remote.lastRPC?.name, "remove_articles_from_collection")
    XCTAssertEqual(remote.lastRPC?.parameters["p_article_ids"] as? [String], [articleID.uuidString])
}

func testSystemTagBatchDeleteUsesOneRPCInsteadOfLoopingPerAsset() async throws {
    try await assetRepository.deleteReadingAssets(ids: [firstID, secondID])
    XCTAssertEqual(remote.rpcCalls.map(\.name), ["delete_reading_assets"])
}
```

- [ ] **Step 2: 运行红灯测试**

Run:

```bash
supabase test db
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -only-testing:DeepReadingVisualPrototypeTests/KnowledgeBaseRepositoryTests
```

Expected: SQL tests report missing table/functions; XCTest reports missing knowledge domain/repository types and batch methods.

- [ ] **Step 3: 实现最小、安全的数据库契约**

迁移必须做以下实际变更：

```sql
alter table public.collections
  add column is_system boolean not null default false;

alter table public.articles
  add column cover_asset_name text not null default 'KnowledgeCoverPlaceholder',
  add column cognitive_dimension text not null default '方法论',
  add column published_at timestamptz not null default now();

create table public.collection_article_exclusions (
  owner_id uuid not null references auth.users(id) on delete cascade,
  collection_id uuid not null references public.collections(id) on delete restrict,
  article_id uuid not null references public.articles(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (owner_id, collection_id, article_id)
);
```

启用该表 RLS，只有 `owner_id = auth.uid()` 可以 select/insert/delete。更新种子使 **往期推文** `is_system = true`；为现有 seed 文章写入真实 Figma 封面资源名、认知维度和固定 `published_at`；补足集合/归属 seed，使首页能验证“最多五项 + 展开”而非依赖客户端假数据。

创建下列三个 `security definer` RPC，均采用 `set search_path = pg_catalog, public`、`auth.uid()` 非空校验、`revoke all ... from public` 后仅 `grant execute ... to authenticated`：

```sql
public.remove_articles_from_collection(p_collection_id uuid, p_article_ids uuid[]) returns void
public.remove_assets_from_tag(p_tag_id uuid, p_asset_ids uuid[]) returns void
public.delete_reading_assets(p_asset_ids uuid[]) returns void
```

第一个拒绝 `collections.is_system`，验证每个文章原本属于该集合，随后 `insert ... on conflict do nothing` 写 exclusion。第二个拒绝 `tags.is_system`，验证 tag/所有资产均归当前 owner 且都关联该 tag，再删除关联。第三个验证请求数组中的每一个资产均归当前 owner，验证通过后单条 `delete from public.reading_assets where id = any(p_asset_ids)` 完成整批删除；任何验证失败都在 delete 前抛出。

- [ ] **Step 4: 实现领域对象和 Supabase 仓储**

在 `Knowledge.swift` 实现 `KnowledgeHomeSnapshot`（`collections`、`tags`）和上文的值类型。`SupabaseKnowledgeBaseRepository` 通过专用 remote 读取 `collections`、`article_collections`、`collection_article_exclusions`、`articles`、当前 owner `reading_assets`；在 Swift 端按 `article_collections.position` 排序、过滤当前 owner exclusion、计算 `visibleArticleCount` 与 `readingAssetCount`。不把这些字段加到 `Article`。

扩展现有 `SupabaseReadingAssetRemote` 的 JSON 参数支持保持 `[String]` 数组；`SupabaseReadingAssetRepository` 的新方法各执行一次对应批量 RPC，禁止遍历 `deleteReadingAsset(id:)`。更新 fake remote 记录所有 RPC 调用以测试“一次调用”。

- [ ] **Step 5: 运行绿灯和安全回归**

Run:

```bash
supabase db reset
supabase test db
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -only-testing:DeepReadingVisualPrototypeTests/KnowledgeBaseRepositoryTests \
  -only-testing:DeepReadingVisualPrototypeTests/SupabaseReadingAssetRepositoryTests \
  -only-testing:DeepReadingVisualPrototypeTests/TagManagementTests
git diff --check
```

Expected: pgTAP 全绿；新仓储测试、已有资产 RPC 测试和系统标签测试全绿；diff 无空白错误。

- [ ] **Step 6: 提交 10.1**

```bash
git add supabase/migrations/202608230001_task10_knowledge_base.sql \
  supabase/seed.sql supabase/tests/008_task10_knowledge_base.test.sql \
  ios_visual_prototype/DeepReadingVisualPrototype/Domain/Knowledge.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Domain/RepositoryProtocols.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseKnowledgeBaseRepository.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseReadingAssetRepository.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/KnowledgeBaseRepositoryTests.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/Fakes/FakeRepositories.swift \
  ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj
git commit -m "feat: add knowledge base data contracts"
```

---

### Task 2 (Task 10.2): 知识库首页与集合详情

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeVisualTokens.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeHomeCoordinator.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeHomeScreen.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/CollectionDetailCoordinator.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/CollectionDetailScreen.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/KnowledgeHomeCoordinatorTests.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/CollectionDetailCoordinatorTests.swift`
- Create: Figma 导出的 `ios_visual_prototype/DeepReadingVisualPrototype/Assets.xcassets/KnowledgeCover*.imageset/`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj`

**Consumes:** `KnowledgeBaseRepository`、`KnowledgeCollection`、`KnowledgeArticlePreview`、Figma 12/12a–d 与 13/14、已有 `ReaderTopProgressiveBlur`、`GlassIconControl`。

**Produces:**

```swift
@MainActor
final class KnowledgeHomeCoordinator: ObservableObject {
    @Published private(set) var snapshot: KnowledgeHomeSnapshot?
    @Published private(set) var collectionsExpanded = false
    @Published private(set) var tagsExpanded = false
    @Published private(set) var failure: KnowledgeHomeFailure?
    var visibleCollections: [KnowledgeCollection] { get }
    var visibleTags: [Tag] { get }
    func load() async
    func toggleCollections()
    func toggleTags()
}

@MainActor
final class CollectionDetailCoordinator: ObservableObject {
    @Published private(set) var collection: KnowledgeCollection?
    @Published private(set) var articles: [KnowledgeArticlePreview] = []
    @Published private(set) var selectedArticleIDs: Set<UUID> = []
    @Published private(set) var isRemoving = false
    func load(collectionID: UUID) async
    func toggleSelection(articleID: UUID)
    func removeSelection() async -> Bool
}
```

- [ ] **Step 1: 写首页、集合红灯测试**

在 `KnowledgeHomeCoordinatorTests.swift` 使用拥有 6 个集合与 6 个标签的 fake repository：

```swift
func testCollapsedGroupsShowOnlyFiveAndFixedEntriesSortFirst() async {
    await coordinator.load()
    XCTAssertEqual(coordinator.visibleCollections.map(\.name), ["往期推文", "A", "B", "C", "D"])
    XCTAssertEqual(coordinator.visibleTags.first?.name, "摘录与思考")
    XCTAssertFalse(coordinator.collectionsExpanded)
    XCTAssertFalse(coordinator.tagsExpanded)
}

func testRecreatedHomeReturnsToIndependentCollapsedGroups() async {
    coordinator.toggleCollections()
    XCTAssertTrue(coordinator.collectionsExpanded)
    let recreated = KnowledgeHomeCoordinator(repository: repository)
    XCTAssertFalse(recreated.collectionsExpanded)
    XCTAssertFalse(recreated.tagsExpanded)
}
```

在 `CollectionDetailCoordinatorTests.swift` 写：普通集合可选择、锁定“往期推文”不会加入选择、移除执行一次 repository RPC、失败时保留原列表及选择、并发的第二次 `removeSelection()` 返回 `false`。

- [ ] **Step 2: 运行红灯测试**

Run:

```bash
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -only-testing:DeepReadingVisualPrototypeTests/KnowledgeHomeCoordinatorTests \
  -only-testing:DeepReadingVisualPrototypeTests/CollectionDetailCoordinatorTests
```

Expected: FAIL，因为协调器、可见条目计算和集合多选移除尚不存在。

- [ ] **Step 3: 按 Figma 实现首页和集合详情**

`KnowledgeVisualTokens` 固化：首页背景 `#F2F2F7`、分组 x=11/w=371/18 pt 圆角、47 pt 行高、`#E5E5EA` 分隔线、34 pt 大标题、21 pt 分组标题、顶部/底部 116 pt 渐进虚化；集合卡 x=11/w=371/h=106/15 pt 圆角、5 pt 间隔、74×78 pt 封面、16/21 标题、11/15 元信息。读取 Figma 13 所需封面，导出到独立 `KnowledgeCover*.imageset`，按数据库的 `coverAssetName` 加载；不导出 Tab Bar 或玻璃控件为图片。

首页两个 44 pt 标题热区独立控制折叠。滚动到紧凑阈值时从 34 pt 大标题切换到固定 17 pt 标题，不改变两个分组的折叠值。集合详情的普通集合以右滑手势进入多选；锁定集合不安装该手势，也不显示移除层。多选态隐藏正常底部栏，在底部渐进虚化前显示“移除”操作；确认后调用 `removeSelection()`，成功才刷新，失败显示“移除失败，请重试。”并保留选择。

相对日期实现为纯函数 `KnowledgeRelativeDate.displayText(for:now:calendar:)`，严格使用：今天、昨天、`N天前`、一周前、当年 `M月d日`、跨年 `yyyy年M月d日`。为每个边界写固定日历/日期断言，不调用系统当前时间。

- [ ] **Step 4: 运行绿灯和视觉构建**

Run:

```bash
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -only-testing:DeepReadingVisualPrototypeTests/KnowledgeHomeCoordinatorTests \
  -only-testing:DeepReadingVisualPrototypeTests/CollectionDetailCoordinatorTests
xcodebuild build \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
git diff --check
```

Expected: 首页/集合协调器测试和 Debug build 通过，新增 Asset Catalog 资源均被 target 引用。

- [ ] **Step 5: 提交 10.2**

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeVisualTokens.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeHomeCoordinator.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/KnowledgeHomeScreen.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/CollectionDetailCoordinator.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/CollectionDetailScreen.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Assets.xcassets/KnowledgeCover*.imageset \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/KnowledgeHomeCoordinatorTests.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/CollectionDetailCoordinatorTests.swift \
  ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj
git commit -m "feat: add knowledge home and collection browsing"
```

---

### Task 3 (Task 10.3): 标签详情与阅读资产卡片复用

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Assets/ReadingAssetListRow.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Summary/ArticleAssetSummaryScreen.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototypeTests/ArticleAssetSummaryCoordinatorTests.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/TagDetailCoordinator.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/TagDetailScreen.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/TagDetailCoordinatorTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototypeTests/Fakes/FakeRepositories.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj`

**Consumes:** `ReadingAssetRepository.readAssets(articleID: nil)`、新增资产批量 RPC、现有 `ReadingAssetCard`/`AssetDraftController`、Figma 09 与 Figma 15–18。

**Produces:**

```swift
@MainActor
final class TagDetailCoordinator: ObservableObject {
    @Published private(set) var tag: Tag?
    @Published private(set) var assets: [ReadingAsset] = []
    @Published private(set) var selectedAssetIDs: Set<UUID> = []
    @Published private(set) var presentedDraft: AssetDraft?
    @Published private(set) var isMutating = false
    func load(tagID: UUID) async
    func toggleSelection(_ assetID: UUID)
    func presentAsset(_ asset: ReadingAsset)
    func beginStandaloneNote()
    func routeToSource(for asset: ReadingAsset) -> ReaderRoute?
    func applySelectionAction() async -> Bool
}

enum TagSelectionAction: Equatable { case removeAssociation, deleteAssets }
```

- [ ] **Step 1: 写共享条目与标签行为红灯测试**

先把当前汇总页的私有 `SummaryAssetRow` 测试锁定为可复用 `ReadingAssetListRow`：关联型条目显示至多三行引用、至多两行笔记、来源标题可点；独立型最多六行、无来源标题；完整非来源区域只调用 `open()`。

在 `TagDetailCoordinatorTests.swift` 写入：

```swift
func testNormalTagSelectionRemovesOnlyThatTagAssociation() async throws {
    try await coordinator.load(tagID: normalTag.id)
    coordinator.toggleSelection(asset.id)
    let succeeded = await coordinator.applySelectionAction()
    let removeRequests = await repository.removeTagRequests
    let deletedIDs = await repository.deletedAssetIDs
    XCTAssertTrue(succeeded)
    XCTAssertEqual(removeRequests, [(normalTag.id, [asset.id])])
    XCTAssertTrue(deletedIDs.isEmpty)
}

func testSystemTagSelectionDeletesTheAssetBatchAtomically() async throws {
    try await coordinator.load(tagID: systemTag.id)
    coordinator.toggleSelection(asset.id)
    XCTAssertEqual(coordinator.selectionAction, .deleteAssets)
    let succeeded = await coordinator.applySelectionAction()
    let deleteBatches = await repository.deleteAssetBatches
    XCTAssertTrue(succeeded)
    XCTAssertEqual(deleteBatches, [[asset.id]])
}

func testSourceRouteUsesTheAssetsAnchorAndKnowledgeOrigin() async throws {
    try await coordinator.load(tagID: normalTag.id)
    let route = coordinator.routeToSource(for: anchoredAsset)
    XCTAssertEqual(route, ReaderRoute(articleID: articleID, anchorID: anchoredAsset.anchor?.id, origin: .knowledge))
}
```

再覆盖：tag 资产按 `createdAt` 倒序；系统 tag 的新独立笔记仅预选系统 tag；普通 tag 的新独立笔记预选当前 tag 并保留系统 tag；RPC 失败不清掉列表或选区；并发重复操作只发一个请求。

- [ ] **Step 2: 运行红灯测试**

Run:

```bash
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -only-testing:DeepReadingVisualPrototypeTests/ArticleAssetSummaryCoordinatorTests \
  -only-testing:DeepReadingVisualPrototypeTests/TagDetailCoordinatorTests
```

Expected: FAIL，因为共享 row 与标签协调器不存在，且现有 summary row 仍是私有实现。

- [ ] **Step 3: 抽取汇总条目并实现标签详情**

将 `SummaryAssetRow` 和其布局 token 移至 `Assets/ReadingAssetListRow.swift`，改名为 `ReadingAssetListRow`/`ReadingAssetListRowLayout`。汇总页只传入 `open`、`showInArticle` 和选中态，保证 Figma 09 的已验收几何、字体、强调色条和点击语义保持不变。

`TagDetailScreen` 用同一条目组件，遵循 Figma 15–18：371×169 pt、8 pt 间隔、关联型 `#F6CF48`、独立型 `#7AA4E7`；上方/底部沿用同一 116 pt 渐进虚化；返回和“添加独立型笔记”使用 `GlassIconControl`。点击任意资产卡片（来源标题按钮除外）在当前标签页上覆盖现有 `ReadingAssetCard`；保存、删卡、改标签成功后重新加载该 tag 资产列表。来源标题仅在有 anchor 的资产出现，点击它生成 `.knowledge` `ReaderRoute`。

普通 tag 多选操作显示“移除”，调用 `removeAssetsFromTag`；系统 tag 显示“删除”，用 Figma 18 的现有/抽取确认样式，并调用批量 `deleteReadingAssets`。两种确认文案清楚区分“仅移除当前标签关联”与“删除后无法恢复”。独立笔记使用 `AssetDraft(anchor: nil, articleID: nil, noteContent: nil, selectedTagIDs: ...)`，交给同一资产卡片自动聚焦键盘；系统 tag 仅选择系统 tag，普通 tag 选择系统 tag 和当前 tag。

- [ ] **Step 4: 运行绿灯与卡片回归**

Run:

```bash
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -only-testing:DeepReadingVisualPrototypeTests/ArticleAssetSummaryCoordinatorTests \
  -only-testing:DeepReadingVisualPrototypeTests/TagDetailCoordinatorTests \
  -only-testing:DeepReadingVisualPrototypeTests/AssetDraftControllerTests \
  -only-testing:DeepReadingVisualPrototypeTests/TagManagementTests
git diff --check
```

Expected: 汇总页回归、标签操作、资产卡片草稿/系统标签全部通过；没有新的资产编辑器或重复 row 视觉实现。

- [ ] **Step 5: 提交 10.3**

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/Assets/ReadingAssetListRow.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Summary/ArticleAssetSummaryScreen.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/TagDetailCoordinator.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Knowledge/TagDetailScreen.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/ArticleAssetSummaryCoordinatorTests.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/TagDetailCoordinatorTests.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/Fakes/FakeRepositories.swift \
  ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj
git commit -m "feat: add tag asset browsing and actions"
```

---

### Task 4 (Task 10.4): 根 Tab 导航、阅读器返回与端到端验收

**Files:**
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift` only if a navigation callback needs a typed route signature
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeUITests/KnowledgeBaseFlowUITests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototypeUITests/Task6To9FlowUITests.swift` only for shared launch/config helpers
- Modify: `ios_visual_prototype/DeepReadingVisualPrototypeTests/AppRuntimeTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/xcshareddata/xcschemes/DeepReadingVisualPrototype.xcscheme`
- Modify: `HADNOFF_MAC.md`

**Consumes:** 10.1–10.3 repositories/coordinators/screens, `ReaderScreen`, current `ArticleAssetSummaryScreen`, `SupabaseRuntimeConfiguration` and existing local-Supabase UI test configuration pattern.

**Produces:**

```swift
enum AppTab: Hashable { case home, knowledge }

enum KnowledgeNavigationDestination: Hashable {
    case collection(UUID)
    case tag(UUID)
    case reader(ReaderRoute)
    case summary(articleID: UUID, origin: ReaderOrigin)
}

struct KnowledgeDependencies: Sendable {
    let knowledgeRepository: any KnowledgeBaseRepository
    let readerDependencies: ReaderDependencies
}
```

- [ ] **Step 1: 写根导航与真实 UI 流程红灯测试**

在 `AppRuntimeTests.swift` 使用注入的 fake runtime，断言 `AppRuntime` 的 `knowledgeRepository` 与 reader repositories 使用同一 `SupabaseClient` 身份，并断言 ready 屏初始选择 `.knowledge`。

在 `KnowledgeBaseFlowUITests.swift` 写以下流程，复用既有公开环境变量注入机制，不在 test source 记录 anon key：

```swift
func testKnowledgeTabOpensTagAssetCardAndReturnsFromAnchoredReader() {
    launchWithLocalSupabaseAndSeededAsset()
    app.tabBars.buttons["知识库"].tap()
    app.buttons["knowledge-tag-摘录与思考"].tap()
    let asset = app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-asset-")
    ).firstMatch
    asset.tap()
    XCTAssertTrue(app.otherElements["reading-asset-card"].waitForExistence(timeout: 3))
    app.buttons["asset-card-dismiss"].tap()
    let source = app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "knowledge-source-")
    ).firstMatch
    source.tap()
    XCTAssertTrue(app.textViews["reader-text-view"].waitForExistence(timeout: 4))
    app.buttons["返回"].tap()
    XCTAssertTrue(app.buttons["knowledge-tag-摘录与思考"].exists)
}
```

测试辅助在运行时通过 `SIMCTL_CHILD_SUPABASE_URL` 与 `SIMCTL_CHILD_SUPABASE_ANON_KEY` 注入，不打印其值；seed asset 在启动后等待真实 RPC 完成再开始断言。

- [ ] **Step 2: 运行红灯测试**

Run:

```bash
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -only-testing:DeepReadingVisualPrototypeTests/AppRuntimeTests \
  -only-testing:DeepReadingVisualPrototypeUITests/KnowledgeBaseFlowUITests
```

Expected: FAIL，因为根视图尚无 Tab、知识库 path、可访问性标识和回退上下文。

- [ ] **Step 3: 接入原生 Tab 与单一知识库导航栈**

`AppRuntime` 从当前 `SupabaseClient` 构造 `SupabaseKnowledgeBaseRepository`，并暴露 `KnowledgeDependencies`，确保对象 identity 与已有文章/资产 repository 共享同一 client。`AppRootView` 在 `.ready` 状态渲染：

```swift
TabView(selection: $selectedTab) {
    HomeUnavailableScreen()
        .tabItem { Label("首页", systemImage: "house") }
        .tag(AppTab.home)

    KnowledgeNavigationContainer(dependencies: dependencies)
        .tabItem { Label("知识库", systemImage: "books.vertical") }
        .tag(AppTab.knowledge)
}
```

`selectedTab` 初始为 `.knowledge`。`KnowledgeNavigationContainer` 只维护一个 `[KnowledgeNavigationDestination]`：集合和标签 push 详情；详情 push `.reader(route)`；阅读器 `onBack` 仅 pop 当前 reader，因而自动返回仍在栈中的集合/标签详情。阅读器打开汇总时 push `.summary`；“在文中显示”先 pop summary，再替换最上层 `.reader` route，确保仍回原详情而非回根页面。`ReaderOriginDismissal` 的旧 feed 语义保留给未来阅读流，不用来重建知识库路径。

给所有用户可见交互加稳定 accessibility ID，包括：`knowledge-home`、`knowledge-collection-{UUID}`、`knowledge-tag-{UUID}`、`knowledge-asset-{UUID}`、`knowledge-source-{UUID}`、`knowledge-open-standalone-note`、`knowledge-confirm-remove`、`knowledge-confirm-delete` 和 `knowledge-home-placeholder`。禁止将资产整卡 `Button` 嵌套来源标题 `Button`；使用同层 `ZStack`/独立 hit region，使“点卡片开资产卡片、点来源标题进阅读器”语义稳定。

- [ ] **Step 4: 全量验证和手工 Figma 对照**

Run:

```bash
supabase db reset
supabase test db
xcodebuild test \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
xcodebuild build \
  -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
git diff --check
git status --short
```

手工验收 iPhone 16：默认知识库 Tab；两个独立折叠区；普通集合移除只影响当前匿名用户；锁定集合没有多选入口；普通标签移除后资产仍在系统标签；系统标签删除后资产与所有标签中均消失；点 tag 资产行开资产卡片；点来源标题精确进入 anchor，返回仍是同一标签详情；新独立笔记预选标签；Figma 12–18 的 116 pt 渐进虚化、卡片尺寸和原生 glass 控件视觉一致。

- [ ] **Step 5: 更新交接并提交 10.4**

在 `HADNOFF_MAC.md` 顶部追加 Task 10 实现、数据库迁移号、验证结果、手工验收状态、未解决风险和下一步；不修改 `docs/PROJECT_STATE.md` 的既有所有权内容。确认 `supabase/.branches/` 与 `supabase/.temp/` 未被暂存后：

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift \
  ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeTests/AppRuntimeTests.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeUITests/KnowledgeBaseFlowUITests.swift \
  ios_visual_prototype/DeepReadingVisualPrototypeUITests/Task6To9FlowUITests.swift \
  ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj \
  ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/xcshareddata/xcschemes/DeepReadingVisualPrototype.xcscheme \
  HADNOFF_MAC.md
git commit -m "feat: integrate native knowledge base navigation"
```

---

## Self-review

### Spec coverage

- 真实数据、展示元数据、owner exclusion、锁定集合、普通/系统标签的原子操作与 RLS：10.1。
- Figma 12–14 的首页、独立折叠、集合浏览、相对日期和范围内移除：10.2。
- Figma 15–18 的标签详情、资产卡片复用、来源 anchor、独立笔记、普通移除与系统删除：10.3。
- 原生 Tab Bar、默认知识库、详情/阅读器返回、真实 local Supabase UI 流程、全量验证和交接：10.4。
- 未纳入：阅读流、AI、通用集合/标签管理、Appetize、发布；符合规格边界。

### 类型一致性

- `KnowledgeBaseRepository` 只提供集合/文章展示与 collection exclusion；资产批量操作保持在 `ReadingAssetRepository`，避免与现有资产卡片双写。
- 所有阅读器跳转使用既有 `ReaderRoute(articleID:anchorID:origin:)`，知识库固定传 `.knowledge`。
- 所有 tag 资产 UI 复用 `ReadingAssetListRow` 与 `ReadingAssetCard`，不复制汇总页或编辑器实现。

### 执行顺序

先完成并审查 10.1，后续任务才能调用已存在的 repository/RPC；10.2 与 10.3 分别生产集合与标签 UI；10.4 只负责把它们接到根原生 Tab 并运行端到端验收。每一项独立提交，最终不创建额外产品 Task。
