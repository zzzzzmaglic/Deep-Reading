# 跨 Session 交接日志

### 开发实现 -> 项目集成与决策

- 日期：2026-08-09
- 状态：本地 Supabase 数据库测试套件已恢复全绿；Task 8 的既有 pgTAP 夹具问题已修复并独立复核通过。
- 修复：`005_atomic_asset_save_and_tag_validation.test.sql` 将测试标签夹具创建移至 `set local role authenticated` 之前，并修正控制字符断言中无效的 `E$$...$$` SQL 字符串写法。生产迁移、RLS、表级权限和 RPC 均未改动。
- 提交：`f7b350b test: fix atomic asset database fixture`。
- 验证：执行 `supabase db reset` 后全部迁移和种子数据成功应用；连续执行完整 `supabase test db`，6 个文件、79 项测试全部通过，包括 Task 8 的 005 与 Task 9 的 006。`git diff --check` 通过；独立安全复核确认 `authenticated` 仍无直接表写权限，私有写入仍仅经 `SECURITY DEFINER` RPC。
- 下一步：项目集成与决策可将 Task 8/9 的数据库验证缺口标记为已关闭，更新 `docs/PROJECT_STATE.md` 并决定是否授权 Task 10。

### 开发实现 -> 项目集成与决策

- 日期：2026-08-09
- 状态：已在本地 Docker/Supabase 环境执行 Task 9 数据库验证；Task 9 的 `006_task9_article_scope.test.sql` 通过，但全套 `supabase test db` 暂未通过。
- 已验证：以项目随附 Supabase CLI 和 Docker Desktop CLI 执行 `supabase db reset`，全部迁移（含 `202608090003_task9_article_asset_scope.sql`）及种子数据均成功应用。随后 `006_task9_article_scope.test.sql` 通过，验证独立型笔记的 `article_id` 持久化、空文章关联与文章范围隔离。
- 新发现的既有测试问题：`005_atomic_asset_save_and_tag_validation.test.sql` 在切换为 `authenticated` 角色后，直接向 `public.tags` 插入测试夹具，触发预期的 `permission denied for table tags`。产品契约要求私有写入经受控 RPC 执行，`authenticated` 不应具有表级 INSERT 权限；因此这是 Task 8 的 pgTAP 夹具设置错误，而非 Task 9 的 schema/RPC 权限回归。该文件此前因本地 Supabase/Docker 不可用而未实际执行。
- 影响：当前全套结果为 6 个文件、69 项断言，其中 001-004 与 006 通过，005 在执行测试主体前失败。Task 9 的数据库范围测试已获得实际通过证据；但数据库测试套件不能标记为全绿。
- 下一步：在继续 Task 10 前，开发实现会话需获授权修复 005 的测试夹具（在切换至 `authenticated` 前创建必要标签数据，保持生产权限不变），重新执行 `supabase db reset && supabase test db`，并独立复核。不得为使测试通过而授予 `authenticated` 对 `tags` 的直接 INSERT 权限。

### 开发实现 -> 项目集成与决策

- 日期：2026-08-09
- 状态：Task 9 已完成实现、第一轮修复和最终 scoped re-review；尚未启动 Task 10。
- 已完成：实现阅读器右上角“当前文章文本标注与笔记汇总”入口、文章汇总页、同一 `ReadingAssetCard` 交互、锚点资产“在文中显示”的替换导航、右滑多选、仅在选中时出现的删除控制及永久删除确认。`在文中显示` 使用替换导航回到对应锚点，回退不会重新进入汇总页。
- 已落实确认的数据模型：新增可为空的 `reading_assets.article_id`。阅读器内创建的独立型笔记写入当前文章 ID；非文章上下文的独立型笔记保持为空。当前文章汇总读取当前文章锚点资产及 `article_id` 匹配的独立型笔记，不混入其他文章或全局独立型笔记。迁移、受控 RPC、Repository/领域模型及数据库/Flutter 覆盖已一并提交。
- 可靠性修复：删除成功后才刷新；摘要刷新失败时保留最后成功内容并显示可重试提示，不再静默呈现为已刷新；资产卡片保存后刷新摘要；新增替换导航历史回归测试。
- 提交：`8612aac feat: add current article asset summary`、`3c2176d fix: surface article summary refresh failures`。
- 验证：实现代理报告 focused summary 9 项、全量 Flutter 89 项、`flutter analyze`、格式检查与 `git diff --check` 均通过；独立复审与 scoped re-review 均无未关闭的 Critical/Important 发现。协调会话尝试复跑 Flutter 时，本机 SDK 在 `flutter.bat.lock` 获取循环中无输出停滞，已终止本会话创建的验证进程，故未在协调会话中重复取得测试输出。
- 残余验收项：当前环境仍无法运行 `supabase test db`（Supabase CLI/Docker 不可用），需在可用环境执行 `supabase db reset && supabase test db`，覆盖新迁移与 `006_task9_article_scope.test.sql`；Windows 环境无法完成 iOS Simulator/真机对右滑、多选删除确认和“在文中显示”返回栈的手工验收。
- 下一步：请项目集成与决策核对 Task 9 的两次提交、已确认的独立型笔记文章归属规则与 PRD/冻结 UX 一致性，并更新 `docs/PROJECT_STATE.md` 后再决定是否授权 Task 10。Task 10 仅应实现知识库浏览与已批准的资产管理路径，不得提前实现 AI 伴读或后续范围。

### 项目集成与决策 -> 开发实现

- 日期：2026-08-09
- 状态：已确认并授权解决 Task 9 的阅读资产文章归属问题。
- 已确认决策：`reading_assets` 增加可为空的 `article_id`。从阅读器创建的独立型笔记必须写入当前文章 ID；在知识库或其他非文章上下文创建的独立型笔记保持 `article_id = null`。带锚点资产仍通过 `asset_anchors.article_id` 关联文章。
- 查询规则：当前文章汇总同时读取锚点属于当前文章的资产，以及独立型笔记的 `reading_assets.article_id` 等于当前文章的资产；不得混入其他文章或未关联文章的独立型笔记。
- 授权范围：开发实现会话可在 Task 9 内增加 Supabase 迁移、受控 RPC/Repository 契约及其数据库/Flutter 测试，并实现当前文章汇总与锚点替换导航。
- 下一步：开发实现会话按 Task 9 的测试先行流程继续实施；仍不得提前进入知识库、AI 伴读、阅读流、离线同步或正式上线范围。

### 开发实现 -> 项目集成与决策

- 日期：2026-08-09
- 状态：Task 9 启动前发现数据模型阻断；尚未开始 Task 9 的实现或测试。
- 已确认问题：Task 9 与已冻结 UX 要求“当前文章的文本标注与笔记汇总”同时展示纯划线、关联型笔记和当前文章内创建的独立型笔记。但当前 `ReadingAsset` 只有 `anchor` 可携带 `articleId`；独立型笔记没有锚点，`reading_assets` 亦未保存可为空的文章关联字段。`readAssets(articleId:)` 只按 `asset.anchor?.articleId` 过滤，因此无法正确读取当前文章的独立型笔记。Task 8 的 `ReaderStandaloneNoteDraftRequest` 虽携带 `articleId`，但 `create_standalone_note_with_tags` 未持久化该值。
- 推荐决策：为 `reading_assets` 增加可为空的 `article_id`（或语义等价的文章关联关系）。从阅读器创建的独立型笔记保存当前文章 `article_id`；在知识库等非文章上下文创建的独立型笔记保持为空。当前文章汇总据此筛选带锚点资产和 `article_id` 等于当前文章的独立型笔记。
- 影响：这是阅读资产的数据生命周期与 Supabase schema/RPC/Repository 契约变更，开发实现会话无权自行引入；不能以漏展示独立型笔记或混入全局笔记的方式继续 Task 9。
- 下一步：请项目集成与决策确认上述关联模型及范围；确认后，开发实现会话将从 Task 9 的失败测试开始，实现迁移、RPC/Repository 契约、当前文章汇总和锚点替换导航。

### 开发实现 -> 项目集成与决策
- 日期：2026-08-09
- 状态：Task 8 已完成，三轮修复后的最终独立复审通过；尚未启动 Task 9。
- 已完成：实现居中悬浮的 ReadingAssetCard，覆盖纯划线、关联型笔记和独立型笔记的查看/编辑态；支持超长划线详情、编辑草稿、放弃编辑确认、删除确认、下拖/外部关闭、标签管理 Bottom Sheet、新建普通标签及系统锁定标签保护。查看态标签确认立即保存，编辑态标签仅暂存并在“完成编辑”时保存。
- Reader 接线：Task 7 的关联资产与独立型笔记请求已接入默认 Reader；创建或编辑带锚点资产后刷新正文高亮，删除带锚点资产后立即移除本地高亮并作最佳努力刷新。卡片打开、标签加载与刷新失败均不会把已成功的写入误报为失败或产生未处理异步异常。
- 技术接口补齐：新增 `create_tag`、`save_reading_asset`、`create_standalone_note_with_tags` 三个受控 RPC 及对应 Repository 方法。它们均以 `auth.uid()`、`SECURITY DEFINER`、受限 `search_path` 和 revoke/grant 约束用户私有写入；其中后两个 RPC 使笔记内容与标签关系在服务端同一事务中保存，避免部分成功。
- 提交：`5f7e221`、`8e926e7`、`0e2a6b2`、`23d747d`。
- 验证：Task 8 presentation 23 项、全部 reading_assets 26 项、Reader presentation 33 项、全量 Flutter 78 项测试通过；`flutter analyze`、格式检查、`git diff --check` 和最终独立复审通过。
- 残余验收项：当前环境无法发现 Docker/Podman 与 Supabase CLI，因此新增迁移和 pgTAP 测试尚未执行；需在已配置本地 Supabase 的环境运行 `supabase db reset && supabase test db`。同时仍需在 iOS Simulator/真机验收卡片拖拽、键盘/焦点、标签 Sheet 键盘态和原生文本选择交互。
- 下一步：请项目集成与决策核对新 RPC 与技术设计/PRD 一致性，更新 `docs/PROJECT_STATE.md` 后再授权 Task 9；Task 9 仅应实现当前文章汇总与锚点返回，不应提前进入知识库或 AI 伴读 UI。

### 开发实现 -> 项目集成与决策
- 日期：2026-08-09
- 状态：Task 7 已完成；首轮实现及可靠性修复均经独立复审通过。尚未启动 Task 8。
- 已完成：阅读器正文支持基于 `SelectionArea` 的真实文本选择；按每个文章块的直接 UTF-16 端点生成单块与跨块 `TextAnchor`；“划线”经现有 `createHighlightAsset` RPC 创建后刷新并渲染持久化高亮；上下文菜单提供划线、复制、打开阅读资产卡片请求与 AI 释义请求，后两者仍仅为契约。阅读器新增独立型笔记的空白草稿请求入口，完整卡片编辑仍属于 Task 8。
- 可靠性修复：不再通过全文字符串反查选区，因此重复文本不会锚定至首个匹配处；操作后关闭菜单并清除选区，防止重复提交；创建/刷新高亮或初始读取资产失败时，正文继续可读且显示可重试的错误提示。修复提交未越界实现 Task 8 卡片 UI 或 Task 11 AI UI。
- 提交：`d221227`（首轮）与 `bd70c58`（可靠性修复）。
- 验证：聚焦选区/菜单/恢复测试通过；`flutter test test/features/reader` 29 项通过；全量 `flutter test` 48 项通过；`flutter analyze`、`dart format --set-exit-if-changed` 和 `git diff --check` 通过；最终独立复审无阻断或重要问题。
- 残余验收项：Windows 环境无法执行 iOS Simulator/真机人工验收；后续需验证长按文本、拖动选区手柄、原生菜单及跨块划线重开文章后的表现。`IosNativeSelectionAdapter` 保持仅声明、未实现，除非 iOS 验收确认 Flutter 默认实现不兼容。
- 下一步：请项目集成与决策核对本条与 PRD、冻结 UX 及技术设计一致性，并更新 `docs/PROJECT_STATE.md`；在明确授权前不得启动 Task 8。

### 项目集成与决策 -> 开发实现

- 日期：2026-08-08
- 已核对：Task 6 的 `aebb1c5`、`9eeddfe`、`e3b1662` 均存在；提交覆盖阅读器、文章读取、锚点与进度恢复、字号/主题偏好、正文点击控件切换及相应修复。
- 确认结论：根据正式交接记录，Task 6 已通过 15 项 reader focused tests、全量 35 项 Flutter 测试、`flutter analyze`、格式检查和最终独立复审；主会话确认 Task 6 完成。当前主会话环境未配置 Flutter，未在此处重复执行测试。
- 授权范围：开发实现会话可按既定实施计划启动 Task 7“文本选择、划线与独立型笔记创建”，仅实现选中文本、划线、关联/独立笔记的入口与持久化。
- 范围边界：不得提前实现资产卡片完整编辑、标签、文章汇总、知识库页面、AI 伴读界面、阅读流、完成阅读报告、完整 AI 搜索、离线同步或正式上线能力。
- 残余验收项：Task 6 仍需在 macOS/iOS Simulator 上人工核验默认排版、主题、锚点定位、进度恢复和正文点击控件；该项不阻塞 Task 7。
- 下一步：完成 Task 7 的测试、验证和独立复审后，再通过根目录正式交接日志提交主会话核对。

### 开发实现 -> 项目集成与决策

- 日期：2026-08-08
- 状态：Task 6 已完成，两轮修复和最终 scoped re-review 均已通过；未启动 Task 7。
- 已完成：实现真实 `ReaderScreen`、文章与文章块读取仓库、五档字号和三种主题、偏好即时持久化、锚点优先于已保存进度的定位规则，以及正文点击切换阅读器控件。阅读进度使用渲染文本计算 UTF-16 偏移，经过防抖后只在在线状态调用现有 `upsert_reading_progress` RPC；离线或写入失败展示可重试的行内错误，不创建离线队列。锚点资产读取失败时正文仍可打开，并显示可重试的锚点定位提示。
- 提交：`aebb1c5`、`9eeddfe`、`e3b1662`。
- 验证：reader focused tests 15 项、全量 Flutter 测试 35 项、`flutter analyze`、格式检查和 `git diff --check` 均通过。首次复审发现锚点键、伪造文章回退、进度/连接语义与测试覆盖问题；第一轮修复复审又发现屏幕到 progress controller 的接线、锚点失败降级、正文点击控件和回归测试缺口；第二轮修复均已关闭，最终独立复审通过。
- 范围边界：未实现 `SelectionArea`、自定义选择菜单、划线、笔记或其他 Task 7 功能；未实现知识库页面、AI 伴读界面、阅读流、完成阅读报告、完整 AI 搜索、离线同步或正式上线能力。
- 残余验证缺口：Windows 环境无法执行 iOS Simulator 验收；在 macOS/iOS Simulator 上仍需按实施计划人工核验默认排版、主题、锚点定位、进度恢复和正文点击控件。
- 下一步：项目集成与决策会话核对本条及 Task 6 提交后，更新 `PROJECT_STATE.md`，再决定是否授权按既定计划启动 Task 7。

### 项目集成与决策 -> 开发实现

- 日期：2026-08-08
- 已核对：Task 5 的 `cae0ae5`、`baa7854`、`88616c7` 均存在；提交内容分别覆盖匿名会话启动、文章读取缓存与偏好、reader / knowledge 路由契约及其修复测试。
- 确认结论：根据正式交接记录，Task 5 已通过全量 19 项 Flutter 测试、`flutter analyze`、格式化检查及最终独立复审；主会话确认其完成。
- 授权范围：开发实现会话可按既定实施计划启动 Task 6“阅读器、偏好、进度与锚点定位”。
- 范围边界：不得提前实现 Task 7 及之后的选择标注、阅读资产交互、知识库页面或 AI 伴读界面；不得实现阅读流、完成阅读报告、完整 AI 搜索、离线同步或正式上线能力。
- 下一步：完成 Task 6 的测试、验证和独立复审后，再通过根目录正式交接日志提交主会话核对。

### 开发实现 -> 项目集成与决策

- 日期：2026-08-08
- 状态：Task 5 已完成，经过两轮修复与独立复审后通过；可按实施计划进入 Task 6。
- 已完成：新增 Supabase 初始化与匿名会话启动、仅含文章元数据和文章块的 Drift 读取缓存、阅读偏好持久化，以及首轮 reader / knowledge 路由契约。首启会创建匿名会话但不替换已有会话；缓存优先返回本地内容，成功刷新后替换，远端文章不存在时清除旧缓存并返回明确错误；reader 路由必须携带 `ReaderRouteContext`，总结页和标签详情页返回 reader 时均使用替换导航并显式传入来源与锚点。
- 提交：`cae0ae5`、`baa7854`、`88616c7`。
- 验证：全量 `flutter test` 通过 19 项，`flutter analyze` 和格式化通过；初次独立复审发现匿名启动、缓存未命中、路由上下文和测试覆盖问题，均已修复。第二次 scoped re-review 最终通过，未发现新 Critical / Important 回归。
- 影响的事实来源：`app/lib/core/`、`app/lib/features/auth/`、`app/lib/app.dart`、`app/lib/main.dart` 与对应测试。
- 范围边界：未实现 Task 6 及之后的阅读器、选择标注、知识库页面、AI 伴读界面或任何后续范围。
- 下一步：开发实现会话可从实施计划 Task 6 开始；继续保留根目录 `docs/HANDOFF.md` 为正式交接日志。

> 本文档记录最近工作、交接输入与待处理事项。正式产品、UX 和技术规则仍以 `PROJECT_STATE.md` 所列领域事实来源为准。

## 当前交接

### 开发实现 -> 项目集成与决策

- 日期：2026-08-08
- 状态：Task 4 已完成，独立复审通过；本轮未开始 Task 5。
- 已完成：AI 伴读网关已补齐持久化匿名用户小时限流、全局日/周令牌预算、原子预留与结算、匿名身份限制、30 天保留清理和本地匿名登录配置。修复了上游 SSE 缺少 `[DONE]` 时错误完成、多块选区上下文截断、结算越额、匿名账户删除后的预留回收、清理锁顺序、上下文 12,000 字符硬上限与 RPC 错误码映射。
- 提交：`4de5f4a`、`bb5ed10`、`89da03d`。
- 验证：`supabase test db` 通过 3 个文件、54 项测试；Deno 网关边界测试 13/13，通过格式和类型检查。第二轮 scoped re-review 已确认五项发现全部关闭，未发现新的 Critical/Important 回归。
- 正式事实来源：`supabase/migrations/202608080001_ai_usage_control.sql`、`supabase/tests/003_ai_usage_control.test.sql`、`supabase/functions/ai-companion/`、`supabase/config.toml`、`docs/demo-environment.md`。
- 残余验证缺口：未用真实 DeepSeek 凭据执行线上流式与取消，也未运行多连接清理/结算压力测试；两项已在执行报告中记录，当前不阻塞 Task 4 验收。
- 下一步：Task 5 现可按实施计划启动。

### 项目集成与决策 -> 开发实现

- 日期：2026-08-08
- 状态：已确认并授权修复 Task 4；在独立复审通过前不得进入 Task 5。
- 已确认：公开匿名 Demo 的 AI 伴读必须新增 Supabase 持久化用量控制，不能依赖 Edge Function isolate 内存。限制由匿名用户小时请求窗口和全局日/周令牌预算共同构成；服务端原子 RPC 必须先预留，再在完成、停止或失败后结算/释放，用于阻止并发或多实例绕过。
- 数据生命周期：用量控制只可记录匿名用户标识、窗口、请求/令牌计数、预留/结算状态与时间；不得保存文章正文、用户问题、笔记或 AI 会话消息。记录保留 30 天后清理。首轮 AI 伴读只接受 `is_anonymous = true` 的匿名身份调用。
- 授权范围：可修改 Task 4 的 Supabase 新迁移、原子 RPC、Edge Function、数据库/Deno 测试、`supabase/config.toml` 和 `docs/demo-environment.md`；将匿名登录启用为 `enable_anonymous_sign_ins = true`，并记录 Demo 项目的 CAPTCHA/Turnstile、配额、AI 开关与 30 天清理配置。
- 同轮修复：补齐上游 SSE 缺少 `[DONE]` 时输出错误而非 `completed` 的测试与实现；修正长文多块选区为先保留锚点邻域、再做整体截断；补充上述网关边界测试。
- 验收门槛：持久化限流/预算的跨用户、跨窗口、并发预留与结算、30 天清理、匿名身份拒绝、SSE `[DONE]` 和多块选区测试全部通过，并完成独立复审后，才可开始 Task 5。

### 开发实现 -> 项目集成与决策

- 日期：2026-08-08
- 状态：Task 4 已完成首轮实现（提交 `4de5f4a`），但独立审查未通过，当前暂停在修复前的跨领域决策点。
- 已确认问题：现有 Edge Function 的内存限流只在单个 isolate 内生效，无法满足公开匿名 Demo 的跨实例请求限流与全局日/周预算控制；技术设计已将该防滥用能力列为首轮约束。
- 需要确认：是否授权将 Task 4 扩展为新增 Supabase 持久化限流/预算记录（迁移、原子 RPC 或等效服务端事务），以匿名用户和时间窗口为维度做跨实例强制控制，并明确记录保留期/清理策略。此项会改变数据生命周期，不能由开发实现会话自行加入。
- 同轮可修复问题：上游 SSE 缺失 `[DONE]` 时不得错误输出 `completed`；长文多块选区必须保持锚点邻域而不是先截取整段；需要补充网关边界测试。上述项不改变产品规则。
- 配置依赖：当前 `supabase/config.toml` 的 `enable_anonymous_sign_ins = false` 与已确认匿名 Demo 边界不一致；Task 4 已在 `docs/demo-environment.md` 记录，待后续获授权的配置变更处理。
- 下一步：项目集成与决策确认持久化限流/预算方案与范围后，开发实现会话再对 Task 4 执行修复与复审；在此之前不进入 Task 5。

### 开发实现 -> 项目集成与决策

- 日期：2026-08-08
- 已完成：首轮实施计划的 Task 1–3 已完成并完成独立复核。Task 1 建立 Flutter 工程、iOS CI 与资源管理；Task 2 完成 Supabase Schema、种子数据、RLS 与所有权约束；Task 3 完成阅读资产与阅读进度的原子 RPC、Flutter 领域模型和仅经 RPC 写入的 Repository。
- 关键结论：Task 2 从空数据库执行 `supabase db reset` 后通过 `supabase test db` 的 15/15 项断言。Task 3 在补强测试后通过 pgTAP 2 个文件、31 项断言，以及 Flutter 资产测试和 `flutter analyze`；独立复核已通过。
- 提交：`ccb98e9`、`eaf03dc`、`c87835a`、`b3e108c`、`ddcde0d`、`8701d92`、`0733ebf`。
- 影响的事实来源：`app/`、`supabase/migrations/202608070001_initial_schema.sql`、`supabase/seed.sql`、`supabase/tests/`、`.github/workflows/`。
- 待确认项 / 风险：Windows Docker Desktop 未开放 Vector 本地日志服务所需的 daemon TCP 端点；本地开发以 `supabase start --ignore-health-check` 启动，数据库、Auth 与 API 服务健康。该处理不改变产品能力或线上部署边界。
- 下一步：仅按已冻结首轮范围进入 Task 4（AI Edge Function 网关）；阅读流、完成阅读报告、完整 AI 搜索、离线同步与正式上线能力仍不进入实现。

### 项目集成与决策 -> 开发实现

- 日期：2026-08-07
- 已完成：已基于 PRD、`UX v1.0 · Design Freeze`、已确认技术设计和跨领域决策，创建正式实施计划：`docs/superpowers/plans/2026-08-07-first-core-user-path.md`。
- 关键结论：计划按十二个可独立验证任务执行，先建立 Flutter/Supabase/AI/CI 基础设施，再完成阅读器、阅读资产、知识库与 AI 伴读；每个任务均包含测试优先、验证和提交步骤。
- 范围说明：仅实现阅读器、文本标注与阅读资产、资产卡片与标签、当前文章汇总、知识库浏览与资产详情、AI 伴读和 iOS Appetize Demo。阅读流、完成阅读与 AI 阅读报告、完整 AI 搜索和正式上线能力仍不进入实现。
- 下一步：由用户选择采用 `superpowers:subagent-driven-development` 的逐任务协作执行，或采用 `superpowers:executing-plans` 在当前会话分批执行；执行前应读取本计划与对应技术设计。

### 项目集成与决策 -> 开发计划

- 日期：2026-08-07
- 已完成：已核对 `2026-08-07-deep-reading-core-path-technical-design.md`、最新 Tech 交接、PRD 与 `UX v1.0 · Design Freeze`。
- 关键结论：Flutter 仅验收 iOS、Supabase 后端、DeepSeek-V4-Pro 流式伴读、匿名隔离 Demo、GitHub Actions -> Appetize 交付链路及在线优先边界均已确认，无 PRD 或冻结 UX 冲突。
- 范围说明：本次实现计划仅覆盖阅读器、文本标注与阅读资产、资产卡片与标签、当前文章汇总、知识库浏览与资产详情、AI 伴读及其导航契约；完成阅读与 AI 阅读报告、阅读流、完整 AI 搜索和正式上线能力留在后续范围。
- 下一步：开发计划 session 可进入 `superpowers:writing-plans`，仅为上述范围生成实施计划。

### Tech -> 项目集成与决策

- 日期：2026-08-07
- 已完成：首轮核心用户路径技术设计已收敛并写入 `docs/superpowers/specs/2026-08-07-deep-reading-core-path-technical-design.md`。
- 关键结论：
  - 分两阶段交付：阶段 A 为求职 Demo（Flutter → GitHub Actions macOS Runner → iOS Simulator `.app` → Appetize 单一链接）；阶段 B 为正式 iOS 上线（在同一架构补正式认证、内容入库/推送、真机签名、TestFlight/App Store）。
  - 首轮使用 Flutter，但只发布和验收 iOS；Android 不在首轮支持范围。Windows/Android 模拟器只辅助通用逻辑开发。
  - 后端采用 Supabase：匿名 Auth + RLS、Postgres、RPC 受控写、Edge Function AI 网关；AI 使用 DeepSeek-V4-Pro 与 SSE 流式输出。
  - Demo 使用固定种子文章、匿名会话隔离与重开重置；真实 AI 受 CAPTCHA、匿名身份限速、会话限流、输出限制与全局预算控制。
  - 首轮在线优先：Drift/SQLite 只做读取缓存；不做离线编辑、同步队列或冲突合并。
  - 已定义但不实现阅读流与阅读器/知识库的路由接口；阅读流视觉与功能留待下一轮。
- 影响的事实来源：新增 Tech 事实来源；不修改 PRD、UX 文档、Figma 或 `PROJECT_STATE.md`。
- 待确认项 / 风险：请项目集成与决策将以上跨领域技术约束登记为确认项；正式上线前仍需确定正式认证方式、数据处理/用户告知、Supabase 部署区域与服务计划、Apple Developer 账号和内容入库/推送方案。UX 既定首轮范围不含完成阅读/AI 阅读报告或完整 AI 搜索，Tech 未纳入实现范围。
- 下一步：项目集成与决策完成登记后，可基于本技术设计启动 `superpowers:writing-plans`，仅为首轮冻结范围制定实现计划。

### 项目集成与决策 -> Tech

- 日期：2026-08-03
- 状态：首轮核心用户路径技术设计正式开始。
- 当前动作：Tech session 按既有交接输入开展技术方案收敛；跨领域问题、阻塞项或需确认的技术约束写入本文件，由“项目集成与决策”处理。

### 项目集成与决策 -> Tech

- 日期：2026-08-02
- 交接目标：启动首轮核心用户路径的技术设计。
- 必读输入：
  - `AGENTS.md`
  - `docs/PROJECT_STATE.md`
  - `PRD.md`
  - `PRD-首轮核心用户路径UX设计.md`
  - Figma `UX v1.0 · Design Freeze`
  - `Intent Recognition and Retrieval Routing Rules.md`
  - `Output Generation Strategy.md`
- 预期输出：技术设计文档，至少覆盖系统架构、核心数据模型、客户端与服务端职责、接口边界、AI 搜索与 AI 伴读链路、状态与错误处理、技术风险及待确认项。
- 约束：不得改变已确认的产品规则或冻结 UX；发现冲突时记录为待确认项，并交由“项目集成与决策”决策。

### 项目集成与决策 -> Prototype / Design

- 日期：2026-08-02
- 当前状态：首轮核心用户路径的 UX 与 Figma 原型已冻结；整个软件仍存在未纳入首轮范围的后续设计工作。
- 权限：在已确认产品规则与本轮设计范围内，Prototype / Design 可直接、高频修改 UX 文档、Figma 页面稿和可点击原型，无需逐次经“项目集成与决策”审核。
- 需交由“项目集成与决策”确认：改变已确认业务规则、数据生命周期、跨模块行为、技术约束或已确认设计范围的事项。
- 冻结后变更：经确认的设计交付改动，由 Prototype / Design 更新同一份 Figma 源文件，并重新执行版本历史、本地副本和 Ready for dev 流程；后续模块按新的设计范围启动独立设计轮次。

## 追加模板

每个 session 在产生实质进展、风险、冲突或待处理工作时，在本节顶部追加一条记录：

```md
### [来源角色] -> [目标角色]

- 日期：YYYY-MM-DD
- 已完成：
- 关键结论：
- 影响的事实来源：
- 待确认项 / 风险：
- 下一步：
```
