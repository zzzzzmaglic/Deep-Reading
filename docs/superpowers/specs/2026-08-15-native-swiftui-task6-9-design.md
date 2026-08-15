# SwiftUI 原生客户端 Task 6–9 设计

**日期：** 2026-08-15

## 目标

将 `ios_visual_prototype/` 从静态视觉验证 App 演进为原生 iOS 客户端，完整实现原 Task 6–9：阅读器、阅读进度与锚点定位；文本选择、划线和独立笔记入口；阅读资产卡片、编辑、标签与删除；当前文章资产汇总与返回原文锚点。

本设计不迁移 Flutter 代码、Riverpod、`go_router`、Drift 或 Dart 测试。它只复用已部署的 Supabase 数据模型、RLS、匿名登录、RPC、种子文章和既有业务规则。

## 不变的后端契约

- `public.articles` 与 `public.article_blocks` 继续是文章事实来源；读取在匿名认证后的 RLS 会话中完成。
- `reading_assets`、`asset_anchors`、`tags`、`asset_tags`、`reading_progress` 继续由 RLS 保护。
- 客户端只用既有 RPC 写入：`create_highlight_asset`、`create_standalone_note`、`update_reading_asset`、`set_asset_tags`、`delete_reading_asset`、`upsert_reading_progress`、`create_tag`、`save_reading_asset`、`create_standalone_note_with_tags`。
- 每个文本锚点仍包含起止 `block_id` 和 UTF-16 offset；Swift 用 `String.UTF16View` / TextKit 的 `NSRange` 计算其值，不能使用 `String.count`。
- `摘录与思考` 锁定标签、同一资产由纯划线变为关联型笔记、硬删除资产及其关系等规则均由 RPC 保持原子性，原生客户端不复制服务端业务判断。
- 服务端密钥和 DeepSeek 密钥仍只存在于 Supabase Edge Function 配置；原生 App 只持有 Supabase URL 与 anon / publishable key。

## 原生架构

### 运行时与配置

App 使用 Swift Package Manager 引入 `supabase-swift`。`SupabaseRuntimeConfiguration` 从 Debug 的未跟踪 `.xcconfig` 或 Xcode Scheme 环境变量读取 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`；缺失时显示可读的配置错误页，不使用静态文章兜底。示例配置文件只记录字段名，不记录 key。

`AppSessionStore` 在 App 启动时检查 `client.auth.currentSession`；无会话时调用匿名登录。`supabase-swift` 管理会话刷新和安全存储。读取、RPC 与 Edge Function 调用都复用该客户端的认证上下文。

### 领域与 Repository

新增 Swift `Codable` / `Sendable` 模型：`Article`、`ArticleBlock`、`TextAnchor`、`ReadingAsset`、`ReadingAssetKind`、`Tag`、`ReaderPosition`。所有表字段使用明确的 `CodingKeys` 映射 snake_case；UUID 在边界处为 `UUID`，向 RPC 发送字符串。

`ArticleRepository` 读取单篇文章和按 `position` 排序的块。`ReadingAssetRepository` 读取资产、锚点、标签与关系后在客户端组合只读视图模型；所有突变仅通过上述 RPC。Repository 协议支持 XCTest fake，不让 View 直接发出 Supabase 查询。

本轮为在线优先：运行期保留内存状态，不引入 Drift 的等价 SQLite 数据库，也不实现本地编辑、重试队列或冲突合并。加载失败、身份失败与 RPC 失败显示显式错误和重试操作。

### 阅读器与选择引擎

SwiftUI 负责 `NavigationStack`、页面状态、Figma 视觉层、iOS 26 Liquid Glass 控件、覆盖态和 Sheet。正文使用一个 `UITextView` 的 `UIViewRepresentable`，由 TextKit 统一绘制多段正文和图片 attachment，以获得原生长按、拖拽手柄、跨段 `NSRange` 选择、滚动定位以及按范围绘制持久化高亮。

每个 block 的 UTF-16 范围在 `ReaderTextLayout` 中保存。选区转换通过范围交集定位首尾 block，计算各 block 内 UTF-16 offset，并从同一 `NSAttributedString` 提取 `selected_text`。高亮资产重新加载后按锚点重建 attributed ranges；跨 block 高亮被分段绘制但仍对应同一服务端资产。

`ReaderCoordinator` 是 `@MainActor` 的 `Observable` 状态对象：加载文章、恢复 progress、优先滚动 route anchor、读取/刷新资产、管理 chrome 显隐、节流阅读进度写入。进度值从当前可见 block 与该 block 的 UTF-16 offset 得出；350ms 节流后调用 `upsert_reading_progress`。请求失败不创建离线队列，显示重试入口。

当前的 Figma 玻璃控件、顶部 148pt Debug 渐进虚化和底部 98pt edge 规则沿用。私有 `CAFilter` 渐进虚化只编译进 Debug / Simulator 的视觉验证配置；Release 使用公开 iOS 26 scroll edge 效果，不引用私有 API。

### 资产、标签与汇总

`ReadingAssetCard`、`AssetEditorSheet`、`TagManagementSheet` 与删除确认均为 SwiftUI 覆盖层。`AssetDraft` 是 value type：保存前保留 note 和 tag 的局部编辑，编辑态的标签改动只有点击“完成编辑”才调用 `save_reading_asset`；查看态立即确认标签则调用 `set_asset_tags`。锁定标签显示但不可取消。

阅读器内的长按菜单提供复制、划线与打开资产卡片；底部独立笔记入口创建无锚点 draft。资产成功写入或删除后，`ReaderCoordinator` 重载资产并更新 `UITextView` 的高亮。

当前文章汇总页使用 SwiftUI `NavigationStack` push，按三种资产形态展示。点击“在文中显示”将汇总替换为同一文章的 Reader route，携带 anchor ID；Reader 优先滚到该锚点。返回行为回到启动汇总前的来源，而不重入汇总。

## 文件职责

- `ios_visual_prototype/DeepReadingVisualPrototype/Configuration/`：运行时公开客户端配置和 Debug 示例。
- `ios_visual_prototype/DeepReadingVisualPrototype/Data/`：Supabase client、文章和资产 repositories、DTO。
- `ios_visual_prototype/DeepReadingVisualPrototype/Domain/`：文章、资产、标签、锚点和进度模型。
- `ios_visual_prototype/DeepReadingVisualPrototype/Reader/`：`ReaderCoordinator`、TextKit bridge、选择转换、阅读器 SwiftUI 页面与 visual tokens。
- `ios_visual_prototype/DeepReadingVisualPrototype/Assets/`：资产卡片、编辑、标签和删除 SwiftUI 覆盖层。
- `ios_visual_prototype/DeepReadingVisualPrototype/Summary/`：当前文章资产汇总与锚点导航。
- `ios_visual_prototype/DeepReadingVisualPrototypeTests/`：模型、选区、draft、repository payload、progress、route-state XCTest。
- `ios_visual_prototype/DeepReadingVisualPrototypeUITests/`：本机 Supabase 环境下 reader→highlight→note→tag→summary→anchor 的 XCUITest。

现有 `ReaderPrototypeModel.swift` 的本地文章仅留给 preview 与测试 fixture；正常 App 路径不引用它。

## 验收标准

1. iPhone 16 iOS 26 Simulator 中，App 匿名登录本机 Docker Supabase，读取种子文章并显示真实 ID 与 blocks。
2. 关闭 Supabase 或移除客户端配置时，页面显示明确错误与重试；不显示本地静态文章。
3. 可跨 block 选择文本，生成持久划线，重启 App 后仍能从 RLS 会话读回高亮。
4. 独立笔记、关联笔记、锁定标签、创建标签、编辑草稿放弃、永久删除均调用既有 RPC 并符合既有业务规则。
5. 滚动进度和“在文中显示”都使用 UTF-16 offset / anchor 定位；路由返回不产生汇总页循环。
6. XCTest 覆盖选区映射、RPC payload、draft 保存语义、锁定标签、progress 节流与路由状态；XCUITest 覆盖本地 Supabase 核心路径。
7. 完成后在 `HADNOFF_MAC.md` 顶部记录原生迁移完成、使用的本机 Supabase 环境、验证命令、未覆盖的 Task 10+ 与 Release 私有 API 限制。

## 明确排除项

- 不修改 Flutter `app/`、Supabase migrations、seed、RLS、RPC 或 Edge Function 代码。
- 不实现 Task 10 知识库、Task 11 AI 伴读、Task 12 Appetize 发布、阅读流、完成阅读、AI 阅读报告、完整 AI 搜索、正式账户或离线写入同步。
- 不把 Debug 私有 `CAFilter` 渐进虚化带入 Release target。
