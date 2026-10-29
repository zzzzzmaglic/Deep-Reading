# 跨 Session 交接日志

### GitHub 展示维护 -> 项目集成与决策

- 日期：2026-10-29
- 已完成：按用户明确要求，将其上传的新版 `PRD.md` 原样替换仓库根目录旧版，README 增加产品需求文档入口。
- 验证：替换后文件与用户提供的文件逐字节一致；9 个 Markdown 配图引用均对应仓库内已有受版本控制的文件；`git diff --check` 通过。
- 范围：文档公开同步，不据此自动修改应用功能、实现范围或 `PROJECT_STATE.md` 中的决策状态。

### GitHub 展示维护 -> 项目集成与决策

- 日期：2026-10-29
- 已完成：按用户确认将公开仓库 `zzzzzmaglic/Private-Tick-Up` 改名为 `zzzzzmaglic/Deep-Reading`，本地主工作区 origin 同步为新 SSH 地址。
- 展示调整：原有 `docs/media/demo.mp4` 上传为 GitHub 视频附件，README 使用附件 URL 内嵌播放器；六张截图、排列、其他文案和视频文件内容保持不变。
- 视频附件：`https://github.com/user-attachments/assets/9baaaef5-bee8-4b6c-85e1-0c8107bdf5e6`。
- 范围：仅仓库元数据与展示文档，不修改应用代码或后端。

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

### GitHub 发布 -> 已公开

- 日期：2026-10-29
- 已完成：现有仓库 `zzzzzmaglic/Private-Tick-Up` 已公开，匿名 GitHub API 确认 `private=false`、默认分支 `main`、许可证 MIT；简介与六个技术主题标签已保存。README、六张新截图与 1 分 5 秒视频均已上传。
- 提交：`7c084a1` 存档展示版本；`dbe4653` 合并 main 的早期文档历史，已推送 main 与 feature/first-core-user-path，没有强制推送。冲突处理中保留当前 PRD 图片路径和较新阶段说明，保留历史交接与早期决策。
- 验证：GitHub Actions 的原生 iOS 构建成功；Flutter 静态检查和 Edge Function 测试失败，尚未修复，不能声称全套 CI 通过。对应运行：`https://github.com/zzzzzmaglic/Private-Tick-Up/actions/runs/40821714794`。

### GitHub 发布 -> MIT 与现有仓库公开

- 日期：2026-10-29
- 用户明确授权采用 MIT、发布现有仓库为公开。新增正式根目录 LICENSE；保留第三方原有许可，不改写历史。准备将当前源码及展示资料存档并快进更新远程默认分支 main。
- 发布检查：可达 Git 历史与未忽略工作区的凭据模式扫描无命中；检查含已知本机服务密钥的精确匹配，未输出凭据。二进制文件不在此文本扫描覆盖范围内。Git diff 空白检查通过，CI 的实际结果需发布后检查。

### GitHub 展示 -> 使用用户新版 README

- 日期：2026-10-29
- 用用户提供的 `README(2).md` 完整替换根目录 `README.md`，不改写文案；逐字节比较一致，六张图片、视频、架构与运行说明的相对链接目标均存在。未提交或推送。

### GitHub 展示 -> README 精简

- 日期：2026-10-29
- 按用户要求删除根 README 的来源说明、源码导航、AI Coding 开发实践及相关入口；保留本地运行、技术实现、功能介绍、六张截图和演示视频。仅精简展示内容，未删除独立参考文档或第三方代码原有许可文件。

### GitHub 展示 -> 截图更新

- 日期：2026-10-29
- 按用户上传顺序将 README 预览替换为六张原始 PNG（`docs/media/showcase-01.png` 至 `showcase-06.png`），上三张、下三张，每张显示宽度 220；第一张使用用户最后补传的知识库首页截图。未裁剪或压缩原图，视频及其他 README 文案保持不变。未提交或推送。

### 开发实现 -> GitHub 项目展示

- 日期：2026-10-28
- 用户要求：公开源码，以视频展示，不在展示 README 中提供 Appetize 在线入口，不增加“当前实现范围”章节；用户已确认演示文章与配图可以公开使用。
- 已准备：重写根 README 与原生客户端说明，新增本地运行、架构、AI Coding 开发实践、第三方来源和 MIT 许可草案；补充无真实凭据的原生构建及后端测试 CI 配置。根目录许可证仍待最终确认，CI 尚未在 GitHub 执行。
- 视频：按用户最新指定的 `dd8aa7e3ca49bee750bdc95a996da09f.mp4` 原样复制到 `docs/media/demo.mp4`，65.334 秒、448×960、约 4.5MB；字节一致性校验通过，并抽查解码画面。从同一视频提取阅读器、AI 伴读、阅读报告预览图。先前生成的大视频和压缩临时文件已移到本机临时备份目录，未删除用户原始视频。
- 边界：保留所有已有源码改动和 Git 历史；本次未提交、推送或更改仓库公开状态。发布前的历史与工作区凭据扫描未命中所检查模式，不构成无泄漏的绝对保证。

### 故障修复 -> AI 伴读云端配置

- 日期：2026-10-28
- 根因：当前 Simulator 安装包连接 `khwlmmamzvwreipjmthz` 云端 Demo。真实请求返回 HTTP 503 / `quota_config_mismatch`，尚未调用 DeepSeek。数据库 `ai_usage_policy` 为每小时 20 次、每日 10000、每周 20000 token；云端函数环境的日/周预算却为 1000000 / 10000000。
- 修复：仅将该云端项目的 `AI_GLOBAL_DAILY_TOKEN_BUDGET` / `AI_GLOBAL_WEEKLY_TOKEN_BUDGET` 同步为数据库现行的 10000 / 20000；没有提高数据库限额、改动模型、密钥或客户端布局。后续调整额度须同时同步数据库策略与函数环境，不能只改 Secrets。
- 验证：CLI 已确认两项配置更新成功；在当前 iPhone 16 / iOS 26.5 Simulator 对失败的普通消息 `Hi` 点击“重新生成”，已收到结合前文引用的完整中文回复；生成停止按钮恢复为输入状态，回复未显示失败提示。无需重建 App；旧失败消息不会自动全部重试。未提交 Git。

### 开发实现 -> Appetize 演示验收

- 日期：2026-10-25
- 问题与根因：Appetize 显示“无法连接阅读服务”。本机使用同一份无签名 Release simulator 包复现；匿名登录成功，但 Supabase 默认 Keychain 存取均返回 `-34018`，后续初始化 RPC 返回 `28000 authentication is required`。此前的“登录时序”推测已由钥匙串错误日志纠正，与 iPhone 16 / 16 Pro 机型差异无关。
- 修复：仅 Release simulator 使用线程安全、实例隔离的 `DemoSessionMemoryStorage`；Debug 和真机保留默认 Keychain。会话初始化必须确认 SDK 能读取会话，否则提前报错。临时诊断日志已移除。
- 验证与交付：Release 通用 Simulator 构建成功；相同上传包在 iPhone 16 / iOS 26.5 本机显示知识库，往期推文数量 4、摘录与思考数量 4。Appetize 更新接口已确认成功，publicKey `pr554yordl2sf6hjw3igrflvxu`，更新时刻 `2026-10-24T14:55:11.197Z`。网页和浏览器自动化连续超时，在线实际启动尚待用户验收；不能据此声称网页端已经验证成功。
- 下一步：结束旧 Appetize 运行会话，再从原链接开始新会话；检查四篇文章与阅读报告。当前修复未提交 Git。先前聚焦 XCTest 遭遇包链接问题，本次证据为 Release 实际运行，不是单元测试通过。

### 开发实现 -> 用户手工验收

- 日期：2026-10-23
- 检查点：开发前已按用户要求提交当时全部阅读报告成果，提交为 `6018f87 feat: add AI reading reports`。
- 已完成：实现 Figma 20/21/22/23 的原生 AI 伴读路径。阅读器右下角入口打开 60% 高度的底部 Sheet；普通提问支持文字输入、SSE 流式回复、停止生成（保留已生成内容）、失败重试与同一阅读器会话内的多轮上下文。选中文字或点击既有划线后选择“AI 释义”，均会带引用打开同一 Sheet；引用显示在输入框上方，并随发送后的用户消息一起展示。
- 服务端约束：`ai-companion` 固定使用 `deepseek-flash`，不读取 `DEEPSEEK_MODEL`、不使用或回退 Pro。每次请求由服务端读取文章标题和全部有序正文块并传入完整文章；客户端不能注入文章正文。最多接收 20 条受长度约束的历史消息，函数不持久化会话。
- Demo 范围：麦克风仅保留 Figma 视觉，不请求权限、不实现语音识别；不实现动态快捷问题，也不展示固定示例快捷问题。
- 验证：iPhone 16 / iOS 26.5 ARM64 `AppRuntimeTests` 为 22 通过、1 项既有配置跳过、0 失败；新增 AI Sheet UI 测试 1/1 通过；Debug 构建成功并已安装启动。使用本机匿名 Supabase 会话完成一次真实 Edge Function 请求，收到 `started`、连续 `delta` 与 `completed`，确认 `deepseek-flash` 和完整文章链路可用。API Key 只注入本机 Edge Runtime 进程，未写入源码、数据库或 Git。
- 下一步：用户在已打开的 Simulator 中验收右下角入口、普通问题、停止生成，以及普通选区/既有划线的“AI 释义”引用路径。当前 AI 伴读改动尚未提交。

### 开发实现 -> 后续开发会话

- 日期：2026-10-23
- 已完成：第二次阅读报告调用新增阅读时长使用边界：只有本次实际加载的报告开头文案明确要求使用阅读时长时，正文才可提及；文章整体概括等其他开头即使基础资料包含时长也不得使用或暗示。该规则已同时写入提示词源模板与用户指定的既有验收 Markdown。
- Demo 规则：第二次调用不再使用“本次认可方式”。管线仍校验第一次调用返回的 `认可方式` 是否符合原分析协议，但在组装第二次调用前会丢弃该字段；最终 system 不再拼接“本次认可方式”文案，最终 user message 的分析 JSON 也不再包含 `认可方式`。
- 提示词同步：已按用户刚更新的 `认知展开文案库.md` 重新生成 `prompt_sources.ts` 的运行时 Base64，并新增 `supabase/scripts/sync-reading-report-prompt-sources.mjs`，后续修改认知文案库或写作基础模板后可再次运行，避免 Markdown 与内嵌运行时内容漂移。
- 验证：认知文案库与写作模板的内嵌编码解码后均与源文件逐字一致；Edge Function bundle 成功；阅读报告管线 5 项单元测试通过，并新增断言确保第二次调用不含认可方式且包含阅读时长条件规则；`git diff --check` 通过。

### 开发实现 -> 后续开发会话

- 日期：2026-10-23
- 已完成：第二次调用提示词的本地导出进一步收窄为仅导出最终 system message。每次生成报告后创建 `*_writing-system-prompt.md`，文件直接从 `# 角色` 开始，保持最终组合提示词的原始 Markdown 换行，不含 JSON 外壳、模型参数、user message、引号或 `\\n` 转义。
- 验证：当前真实调用的结构化捕获已可重新导出为 Markdown；导出器仍仅作用于本机 Git 忽略目录，托管环境默认不捕获。
- 下一步：用户直接检查 Markdown 文件，不再查看 `_writing-prompt.json`。

### 开发实现 -> 后续开发会话

- 日期：2026-10-23
- 已完成：本地调试捕获已从“第一次调用的分析输出”切换为“第二次调用的最终输入”。函数在第二次 `deepseek-flash` 请求前记录实际模型参数以及最终的两条 messages：完整组合后的 system 提示词和包含真实文章/资料的 user 提示词；第一次调用输出不再产生新的捕获。
- 自动导出：运行中的 `supabase/scripts/export-reading-report-writing-prompts.sh` 会为每次报告自动创建 `*_writing-prompt.json` 到 Git 忽略目录 `supabase/.debug/reading-report/`。电脑重启后需重新启动该脚本；`--once` 可导出当前 Edge 容器日志里已有的第二次调用提示词。
- 验证：已真实生成第一篇报告并自动输出 `20261023T065052Z_10000000-0000-0000-0000-000000000001_a63fb413-a18c-4aee-b9d2-36a0adab81e1_writing-prompt.json`。文件为有效 JSON，模型为 `deepseek-flash`，包含两条 messages；最终 system 3172 字符、user 19314 字符，且不存在未替换的 `{{...}}` 模板占位符。API Key 未写入文件。
- 下一步：用户检查该文件中 `request.messages[0].content` 的最终组合 system 提示词，以及 `request.messages[1].content` 的第二次调用 user 输入。

### 开发实现 -> 后续开发会话

- 日期：2026-10-23
- 已完成：阅读报告第一次认知分析及其可选重试现支持本地 JSON 捕获。每次尝试会记录原始模型响应、校验后的结构（若有效）、校验错误（若无效）、文章 ID、尝试次数、时间与同一报告请求的 `captureId`；不记录文章全文、组装提示词、API Key 或未选中的阅读资产。
- 安全边界：捕获在本机 `kong` / loopback Supabase 环境自动启用，托管环境默认关闭；可用 `READING_REPORT_CAPTURE_ANALYSIS_JSON=true|false` 显式覆盖。捕获先写入结构化 Edge Runtime 日志；本机导出器 `supabase/scripts/export-reading-report-analysis-captures.sh` 持续跟随当前 Edge 容器并自动为每次尝试写入 Git 忽略目录 `supabase/.debug/reading-report/`，不得提交。
- 验证：新增回归断言覆盖“首个原始非 JSON 响应及校验错误被捕获、重试后的有效原始 JSON 和解析对象被捕获”；Edge Runtime 已热重载，测试入口可完整打包，`git diff --check` 通过。导出器现已运行，并用第二篇文章完成真实自动落盘验收：没有手工提取即生成 `20261023T064022Z_10000000-0000-0000-0000-000000000004_e4c354fa-5b44-4406-a986-d49dd9f32b5d_attempt-1.json`，文件与其中的原始响应均通过 JSON 校验。
- 实际验收：已用本机临时匿名 Demo 会话真实生成第一篇报告，捕获 `captureId=aa048efe-8e8a-4eb5-8ed0-497058dd49b4` 的首次有效分析，并导出到 Git 忽略目录 `supabase/.debug/reading-report/2026-10-23T062610Z_10000000-0000-0000-0000-000000000001_attempt-1.json`；JSON 语法校验通过。历史调用未保存原始响应，无法回补。

### 开发实现 -> 后续开发会话

- 日期：2026-10-23
- 已完成：四篇阅读报告 Demo 关联型笔记已压缩到约原文一半，实际长度依次为 82、86、87、89 个字符；核心思考保留，但不再追求覆盖原笔记全部细节。新建 Demo 用户会直接获得短版文案；新增数据迁移仅替换仍与旧默认文案完全一致的既有笔记，不覆盖用户自行修改过的内容。
- 验证：迁移 `202610230001_shorten_reading_report_demo_notes.sql` 与 `202610230002_use_short_reading_report_demo_notes.sql` 已应用到本机 Supabase；后者仅把内容完全等于旧默认文案的新写入转换为短版，不删除资产。数据库实际查询确认四篇均为短版文案。阅读报告 Demo pgTAP 9/9 通过，并新增每条 Demo 笔记不超过 100 字的回归约束。
- 下一步：重新进入资产卡片或阅读器以刷新当前数据，并生成四篇报告观察较短笔记对报告聚焦程度的影响。

### 开发实现 -> 后续开发会话

- 日期：2026-10-23
- 已完成：阅读报告第一次“认知分析 JSON”响应若未通过既有协议校验，会以同一个 `deepseek-flash` 模型、相同参数、相同已组装提示词自动重试一次；仅协议校验失败触发重试，网络错误和第二次报告写作调用不重试。两次分析输出 token 均会计入实际用量，重新启用用量控制时的预留上限已同步覆盖“一次分析重试 + 一次写作”的最坏情况。
- Demo 用量：当前阅读报告 Demo 默认跳过 `reserve_ai_companion_usage` / `settle_ai_companion_usage`，因此不受每小时次数、每日及每周 token 预算影响。正式需要恢复限制时，给 Edge Function 设置 `READING_REPORT_USAGE_LIMITS_ENABLED=true` 即可重新启用原有控制；该变更只作用于阅读报告，不改变 AI 伴读的限额。
- 验证：新增回归测试覆盖“首个分析响应不是 JSON → 相同请求重试 → 第二次分析有效 → 写作成功”，并断言默认 Demo 路径不调用用量 RPC。Supabase Edge Runtime 已检测文件变更并成功重新加载 `reading-report`。
- 下一步：在 Simulator 再次生成报告，确认原先的 `global_daily_budget` 不再阻断；如 DeepSeek 连续两次返回不合规分析，仍按既有无法生成状态处理。

### 开发实现 -> 后续开发会话

- 日期：2026-10-23
- 已完成：阅读报告已接入 Supabase Edge Function 与 iOS 阅读器。服务端从数据库读取文章全文与当前匿名用户的阅读资产，只在非空笔记中按“笔记正文可见字符数最多 → 更新时间最新 → 稳定 ID”选择唯一写作依据；关联型笔记不计算引用/划线文字。无有效笔记时不调用模型，客户端在报告正文区显示“无法生成”。有有效笔记时固定使用 `deepseek-flash` 完成“认知分析 JSON → 报告正文”两次调用，任何情况下均不使用 Pro 或自动降级到 Pro。API 密钥仅作为 Edge Function 运行时环境变量注入，未写入源代码、数据库或 Git。
- Demo 数据：四篇文章会各创建一条不超过 300 字的关联型笔记；第一篇原有阅读资产会由版本化 Demo 初始化逻辑一次性清理。当前仅第一篇《1600—2100 年的公司简史》已有经用户提供的完整原文并写入 `article_full_texts`，且真实端到端生成成功。其余三篇的原始 RTF 已不在本机，绝不能以阅读器节选冒充全文，需用户重新附加后再导入并验收。
- 授权与数据边界：用户已明确允许将四篇文章全文和算法选中的单条笔记发送给 DeepSeek，用于阅读报告生成与验收；不得发送其他笔记、划线引用或用户无关数据。
- 验证：本地 pgTAP 全量 10 文件 / 110 项通过；iPhone 16 / iOS 26.5 ARM64 `AppRuntimeTests` 18 项执行、1 项配置性跳过、0 失败；第一篇真实 `deepseek-flash` 两阶段调用已返回有效报告。密钥泄漏扫描与 `git diff --check` 在清理正文尾随空格后应再次执行。
- 运行与排版补充：本地验收必须保持 `supabase functions serve` 运行并临时注入 `DEEPSEEK_API_KEY`；停止该进程会让 App 显示“阅读报告暂时无法生成”。报告正文的 UIKit 文本容器已补充 SwiftUI `sizeThatFits`、TextKit 宽度跟随与中文逐字换行，确保在 Figma 的 273×234 pt 区域内以 13 pt / 20 pt 行高多行两端对齐。对应多行布局 XCTest 已通过，并已安装至 iPhone 16 Simulator。
- 下一步：用户重新提供包含余下三篇完整原文的 RTF；导入并清理多余空格，重置本地 Demo 数据，分别执行三篇真实报告验收，再进行 Simulator 手工 UI 验收。不要提交或记录 API 密钥。

### 开发实现 -> 用户手工验收

- 日期：2026-10-22
- 已完成：根据用户本轮明确扩展的 Demo 范围，已实现 Figma `31 阅读器 · 文章末尾完成阅读（来自阅读流）` 到 `24 AI 阅读报告 · 返回原入口` 的完整路径。完成按钮作为文章末尾的真实滚动内容呈现；点击后显示 317×388 pt 阅读报告卡片，正文容器为 273×234 pt、13 pt 字号、20 pt 行高与两端对齐，当前依需求留空并用蓝线显示边界。底部按钮使用 iOS 26 原生可交互 Liquid Glass，严格为 44×44 pt，点击后退出阅读器并返回上一页。报告已从 SwiftUI `fullScreenCover` 改为与笔记卡片共用的 UIKit 自定义 presentation：报告内容直接出现在最终位置，无位移/淡入/缩放；独立的 20% 灰色 dimming view 仅按笔记卡片的方式渐显，不再从底部推入整层页面。
- 关键结论：四篇 Demo 文章的专注时长按展示顺序固定为 40/20/10/36 min，深度对话固定为 10 次；“划线笔记”使用当前文章的实际阅读资产数量（上限 99）。当前完成操作完成 Demo 导航路径，尚未向后端写入正式“已完成阅读”状态。
- 影响的事实来源：Figma nodes `858:2009` 与 `130:473`，以及用户本轮对完成阅读/报告路径的明确扩展授权。
- 验证：iPhone 16 / iOS 26.5 ARM64 上，固定数值/尺寸与完成按钮回调的 2 项 XCTest 通过；“文章末尾→报告→返回知识库来源页”端到端 UI Test 通过，并导出截图完成 Figma 几何与 44 pt 按钮的视觉核对。
- 下一步：用户在 Simulator 手工验收文章末尾按钮的滚动位置、报告卡片和返回手感；正式阅读完成状态持久化待后续产品/数据契约确认后实现。

### 开发实现 -> 用户手工验收

- 日期：2026-08-31
- 已完成：合集详情、标签详情、阅读器和当前文章汇总页已统一改用 `NavigationStack` / `UINavigationBar` 的系统原生 Back。四个页面原本自建的 `.topBarLeading` 按钮、`.navigationBarBackButtonHidden(true)` 以及手动 `path.removeLast()` 回调已移除；返回点击、页面 pop、按压反馈与侧滑返回均由系统导航栈统一管理。阅读器/标签页右侧工具按钮保持不变。
- 阅读资产卡片层级补充：阅读器、当前文章汇总页和标签详情页已改为 item-driven 的系统 `fullScreenCover`。系统导航栏保持挂载，但位于全屏卡片层之下且不可点击；卡片关闭时由系统完成整屏转场，不再单独切换导航栏显隐。表示项保留 draft/token 稳定快照，避免 dismiss 过渡期间源状态提前清空。
- 确认弹窗与键盘：`fullScreenCover` 内再呈现 SwiftUI `alert` 或 `UIAlertController` 都会让 iOS 26 强制隐藏当前软件键盘，无法满足已确认的“弹窗前后键盘状态不变”。删除与放弃编辑确认因此保留在同一全屏卡片层内，不创建第二个系统 presentation；键盘原本显示则全程显示，原本隐藏则不会被唤起，确认/取消语义不变。
- 根因：旧实现在 pop 过程中同时存在“当前页自建按钮的按压回弹”与“目标页新 leading toolbar item 的进入/玻璃重组”，因而视觉上像连续弹动两次。
- 验证：回归 UI Test 先在旧的 `reader-back` 自定义按钮上按预期红灯；修正后，阅读器原生 Back、汇总返回阅读器、合集返回知识库、标签页原生 Back + 右侧新建笔记共 4 个 UI Test 通过；阅读器/汇总滚动边缘与标题的 3 个 UIKit 运行时测试通过。阅读器、汇总页、标签详情页的层级回归共 3 条通过，均确认全屏卡片会拦截导航栏交互；删除确认与放弃编辑确认的 2 条键盘 UI 回归通过，弹窗出现及取消后键盘均保持显示。
- 下一步：用户在 iPhone 16 Simulator 手工确认四类页面的原生 Back 仅有一次完整按压回弹，并确认侧滑返回手感。

### 开发实现 -> 用户手工验收

- 日期：2026-08-30
- 已完成：阅读器现在使用真实的居中系统导航标题“每日推文”，并保留 `UITextView` 通过 UIKit 公共 `setContentScrollView(_:for:)` API 注册为顶部导航栏内容滚动视图的实现。单击正文及上下滑动控制顶部/底部控件显隐的既有状态机保持不变。
- 关键结论：显式注册 `UITextView` 是系统跟踪阅读器滚动位置的必要条件，但空的 inline 导航标题仍只会出现泛白边缘。同机 A/B 确认，真实的导航标题会让系统建立与知识库首页一致的标题型顶部合成与渐进虚化。
- 验证：新增真实 UIKit 层级测试，先在空标题实现上红灯，改为“每日推文”后绿灯；阅读器相关 14 个 XCTest 与 1 个 UI Test 均通过。iPhone 16 / iOS 26.5 Simulator 截图确认标题居中显示，文章内容在其后方按系统顶部滚动边缘逐渐虚化。
- 下一步：用户在 Simulator 手工验收顶部滚动虚化，以及单击、上滑、下滑切换导航控件显隐的触感。

### 开发实现 -> Task F 本机 UI 验证完成，待手工验收

- 日期：2026-08-20
- 已完成：真实本机 Supabase UI 验证已在 iPhone 16 / iOS 26.5 ARM64 通过：阅读器 → 当前文章汇总 → `在文中显示` → 返回同一阅读器。共享 Scheme 的 TestAction 环境仍不会传入 UI Test runner；验证改为只存在于临时目录的 `.xctestrun` 同时注入 runner 与被测 App，并在每次运行后删除。
- 关键结论：验证暴露并修复了两项测试路径竞态/语义问题：异步测试划线尚未可读时过早打开汇总页，以及资产行容器的可访问性标识吞掉 `在文中显示` 子按钮。现在测试显式等待真实划线可读，资产行主按钮与“在文中显示”各有独立的可访问性元素；正常用户流程不改变。
- 验证：`Task6To9FlowUITests.testReaderAssetSummaryReturnsToAnchoredReader` 以 `xcodebuild test-without-building` exit 0 通过；`ArticleAssetSummaryCoordinatorTests` 聚焦 XCTest 以 `xcodebuild test` exit 0 通过；`git diff --check` 通过。临时公开配置未写入项目或 Git，未连接远端或生产数据。
- 待确认项 / 风险：用户仍需在 Simulator 手工确认汇总卡片视觉、右滑多选与删除操作。保留既有 `UIScreen.main` 弃用与 Assets 图集警告；本轮不处理。
- 下一步：等待 Task F 手工验收反馈；不扩展到 Task 10+。

### 开发实现 -> 用户手工验收

- 日期：2026-08-20
- 已完成：阅读资产卡片引用区取消额外添加的中文引号，现忠实显示已保存的原文选区；数据、划线、标签、笔记和卡片几何均未改变。
- 验证：新增显示格式化回归测试先因规则缺失编译红灯，最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 18/18 通过；Debug App 已重装并启动。
- 待确认项 / 风险：用户需打开关联型阅读资产卡片，确认引用文本两侧没有装饰引号。未提交或推送。
- 下一步：继续按用户具体现象处理。

### 开发实现 -> 用户手工验收

- 日期：2026-08-20
- 已完成：本机 Mac Supabase 已实际应用系统保底标签迁移 `202608190001_system_tag_invariant.sql`，并应用兼容迁移 `202608200001_make_asset_tag_rpcs_idempotent.sql`。兼容迁移只为两条既有独立笔记 RPC 的 `asset_tags` 写入增加 `(asset_id, tag_id)` 冲突忽略，避免资产触发器已自动关联“摘录与思考”后重复插入；没有重置或删除验收数据。
- 关键结论：系统标签现在是数据库不变量：认证用户创建时自动拥有锁定的“摘录与思考”，任意新阅读资产自动关联它；Swift 端只显示为置顶且锁定选中，不依赖用户创建或预先读取成功。
- 验证：完整本机 pgTAP 为 7 文件 / 83 项 / 0 失败；iPhone 16（iOS 26.5，ARM64）完整 XCTest 为 113 通过、2 个配置跳过、0 失败。Debug App 已安装并启动在阅读器首页；未提交、未推送。
- 待确认项 / 风险：用户需在资产卡片的 `#标签` 页面手工确认系统标签最上、锁定、默认选中，并确认新划线/非空独立笔记会自动持有它。青绿色正文行框是既有排版辅助，非本次变更。
- 下一步：等用户给出验收现象后再局部处理；不要据此扩大任务范围。

### 开发实现 -> 后续开发会话

- 日期：2026-08-19
- 已完成：按 PRD §2.1.4/§2.2.5 的系统保底标签规则，新增每用户“摘录与思考”的数据库不变量迁移与 Swift 客户端时序修复。新认证用户自动建系统标签，既有用户回填；所有新阅读资产自动关联，历史资产补齐；客户端允许后端在首次资产创建时供应真实系统标签，并将系统标签固定排在普通标签之前、锁定选中。
- 验证：Swift TDD 红灯为 `missingSystemTag` 与系统标签排序失败；修复后资产/标签聚焦 24/24、完整单元测试 114 executed / 1 expected skip / 0 failed。数据库 pgTAP 在迁移应用前按预期 4/4 红灯。
- 待确认项 / 风险：本地迁移应用命令被 Codex 自动授权额度限制拒绝，当前 Mac Supabase 实例尚未应用 `202608190001_system_tag_invariant.sql`，因此数据库 pgTAP 绿灯和 Simulator 手工验收尚未完成。
- 下一步：授权恢复后执行本地 migration up（或经允许 reset）、完整 `supabase test db`，再重建 Simulator App 验收固定标签。

### 开发实现 -> 后续开发会话

- 日期：2026-08-19
- 已完成：修复 05a/06d 确认弹窗在软件键盘下方显示的问题。根因是普通 SwiftUI `ZStack` 只能绘制在 app 主窗口，而 iOS 26 软件键盘由系统独立合成；实机验收进一步证明应用自建 `UIWindow` 即使提升至极高 raw level 也仍会被远程键盘盖住，因此已放弃自建窗口方案。删除和放弃编辑确认现改用 SwiftUI/UIKit 原生系统 `alert`，由系统负责在键盘之上合成遮罩、弹窗及操作按钮；代码不调用 `resignFirstResponder`，不主动改变键盘显隐。
- 键盘保持补充：原生 alert 能正确位于键盘之上，但首次手工验收发现其出现会让 SwiftUI `TextEditor` 暂时失去焦点。`AssetEditorView` 现接受显式 focus request；仅当弹窗出现前键盘已经显示且卡片处于编辑态时，在系统 alert 安装完成后恢复同一个编辑器焦点。弹窗前键盘隐藏时不会主动唤起，因此仍遵循“出现前是什么状态，出现后保持该状态”。
- 验证：iPhone 16 / iOS 26.5 的原生 alert + 焦点恢复 Debug 构建通过并已重新安装、启动（`xcodebuild build` exit 0）；保留既有 `UIScreen.main` 弃用警告。未提交。需用户在 Simulator 手工确认两种系统弹窗均覆盖、压暗键盘，键盘保持显示，取消/确认入口可点。
- 影响文件：`ios_visual_prototype/DeepReadingVisualPrototype/Assets/ReadingAssetCard.swift`、`Assets/DeleteAssetConfirmation.swift`。
- 下一步：仅按用户对弹窗层级与键盘保持的验收结果微调；不扩展产品范围。

### 开发实现 -> 后续开发会话

- 日期：2026-08-19
- 已完成：修复 05a/06d 确认弹窗按钮区消失的问题。根因是弹窗内部以 `offset` 放置内容，但容器在固定尺寸前按子视图固有尺寸居中布局，导致 69 pt 操作区落到 22 pt 圆角裁切范围外。现改为自然纵向布局：28 pt 顶距 + 23 pt 标题 + 13 pt 间距 + 40 pt 说明 + 28 pt 留白 + 1 pt 分隔线 + 69 pt 操作区，合计精确 202 pt；取消/继续编辑与删除/放弃编辑入口均恢复显示和完整点击区域。
- 关键结论：放弃编辑与资产删除确认弹窗不再主动改变键盘或卡片位置。弹窗出现前键盘显示则继续显示，出现前隐藏则继续隐藏；取消弹窗同样保持原状态。
- 验证：`AssetDraftControllerTests` 与 `TagManagementTests` 在 iPhone 16 / iOS 26.5 通过（xcodebuild exit 0）；Debug app 已重建、重装并启动。未提交。
- 影响的事实来源：Figma `05a`（`501:887`）与 `06d`（`618:1199`），以及用户明确覆盖规则“弹窗不得改变键盘显隐状态”。
- 下一步：等待用户在 Simulator 复查弹窗按钮和键盘保持。

### 开发实现 -> 后续开发会话

- 日期：2026-08-19
- 已完成：已通过 Figma MCP 精确读取 `05a 阅读资产卡片 · 删除确认`（`501:887`）、`06d 阅读资产卡片 · 放弃编辑确认`（`618:1199`）以及独立型笔记编辑 Frame（`397:537`）。删除与放弃编辑确认统一实现为 Figma 固定 313 × 202 pt 白色弹窗：标题/说明/分隔线与蓝色左操作、红色右操作均按节点参数；放弃编辑会先收起键盘，并让编辑卡片保持 Figma 06d 的 y=94 位置。普通查看态资产卡片恢复为 Figma 05a 的 345 × 460 pt 布局；编辑态维持 345 × 400 pt。
- 关键结论：卡片关闭是否弹出“放弃本次编辑”只由未保存且非空的笔记正文决定。进入编辑态、仅改标签、输入后清空、空白独立型笔记均直接关闭；既有非空笔记未改变也直接关闭。独立型笔记编辑区现为 Figma 的 x=20/y=24、305 × 310，光标在顶部；底部始终显示删除图标，尚未落库的草稿点击该图标走同一关闭/放弃判定。底部“独立笔记”按钮补了完整 44 × 44 pt 命中区域，不再只能点中 14 pt 图标。
- 验证：修复后的 `AssetDraftControllerTests` 与 `TagManagementTests` 已在 iPhone 16 / iOS 26.5 通过（xcodebuild exit 0），并重新证明同名新建标签单飞；Debug app 已重建、重装并启动。另一次含 `ReaderCoordinatorTests` 的扩展复跑暴露两项既有 progress throttle 时序测试失败（写入较早 offset 2/1，而断言期望 4/2），与本轮资产卡片路径无直接关系，尚未修改。当前构建有 `UIScreen.main` 的 iOS 26 弃用警告（既有键盘高度计算路径），不影响构建或运行。
- 影响的事实来源：Figma 节点 `501:887`、`618:1199`、`397:537`。
- 待确认项 / 风险：需用户在 Simulator 手工确认弹窗、独立笔记键盘与 44 pt 工具栏命中区；当前工作树未提交。
- 下一步：根据手工验收反馈做局部调整。

### 开发实现 -> 后续开发会话

- 日期：2026-08-19
- 已完成：已通过 Figma MCP 精确读取 `06b 阅读资产卡片 · 编辑态删除确认`（`502:899`）与 `06c 阅读资产卡片 · 编辑态有未保存修改（键盘）`（`618:1061`）。SwiftUI 编辑态卡片改为 Figma 的 345 × 400 pt：引用区 305 × 100（x=20/y=24）、透明可滚动笔记输入区 305 × 190（x=20/y=144）、标签/删除/完成控件分别以 44 pt 热区固定在底部；键盘出现时按 Figma 的 393 × 852 画板上 y=94 定位。删除确认改为 Figma 的白色 313 × 202 pt、22 pt 圆角、分隔按钮布局与 35% 背景遮罩。当前不是编辑器没有焦点：蓝色输入光标表示焦点已成功设置；若 Simulator 仍未显示软件键盘，应在 Simulator 使用 Cmd+K，或 I/O > Keyboard > Toggle Software Keyboard / 关闭 Connect Hardware Keyboard。
- 关键结论：7 个演示标签（产品灵感、决策框架、人物、商业化、时间管理、写作练习、长期主义）会在 Debug 原型第一次打开资产卡片时，针对当前匿名用户幂等创建；不写入 Supabase 共享 seed、不会出现在 Release。重复打开或并发卡片不会重复创建已有标签。
- 验证：iPhone 16 / iOS 26.5 聚焦 `TagManagementTests` 与 `AssetDraftControllerTests` 通过（`xcodebuild test` exit 0）；新加测试覆盖 Debug 标签仅创建缺失项。Debug app 已重装并启动到 Simulator。当前工作树仍有前序阶段 C–E 及本轮的未提交变更。
- 影响的事实来源：Figma 06b/06c（上述 node IDs）、`PRD-首轮核心用户路径UX设计.md` §4。
- 待确认项 / 风险：尚需用户以打开软件键盘的 iPhone 16 Simulator 手工核验 06b/06c 的实际像素观感；当前正文青绿色行框仍是用户先前开启的排版验收辅助，不是资产卡片样式。
- 下一步：仅按用户验收反馈微调卡片或标签页，不扩展后续模块。

### 开发实现 -> 后续开发会话

- 日期：2026-08-18
- 已完成：已再次清空本机 Mac Supabase 验收数据中的 2 条 `reading_assets`（清理当时为 0 条，后续用户验收可能已新增）；阅读器排版调整为标题 30 pt / Bold、正文 20 pt、段落间距 30 pt，正文统一为 28 pt 固定行框；图片附件使用独立自然高度段落样式。持久划线改为逐个 TextKit 字形行片段的 3 pt 黄色底部划线，现以 `lineRect.maxY + 1 pt` 定位在行框下方，不再使用会覆盖段落 leading 的 UIKit `backgroundColor`，跨多行划线会覆盖每一行。当前为用户排版验收临时打开了青绿色 TextKit 行框可视化（`ReaderLineFrameDebug.isEnabled = true`）；用户确认正文 `baselineOffset = 2 pt` 为正确值，正文字符、零宽保护位与段落末尾换行符现统一使用 20 pt 字体、28 pt 行框及同一基线偏移，避免段落末行因换行符回落到 UIKit 默认字体指标而出现不同留白。标题/图片使用自然高度行框，段落间隔会显示为空框，仍待用户在 Simulator 目视确认最终平衡。点击既有划线的命中坐标已改为 UITextView 实际滚动坐标，并提供原生 iOS Edit Menu（取消划线、打开资产卡片、AI 释义、复制、标签管理）。菜单位置以资产首个字形的稳定锚点计算，因此同一条跨多行划线无论点击哪一行，菜单位置不变；菜单已展开时，正文点击不会重复触发打开动画，点击菜单外仅关闭菜单而不切换阅读器控件显隐。原生选择的拦截改为“选区与划线范围相交”而非只检查选区起点，并在命中时取消 UIKit 延迟调度的普通编辑菜单，因此双击划线不会再出现未划线文本的菜单。每个正文段首增加仅参与排版的零宽保护位，并在选择变化时把起止点收紧至真实正文，以避免普通选区手柄延伸进 30 pt 透明段落间隔；该保护位不会进入复制文本或持久化锚点。UIKit 没有公开的“单独下移系统蓝色选区矩形”参数，仍保留原生选区、手柄与菜单几何，未使用私有 API。资产卡片固定为居中 345 × 460 pt；编辑输入与新建标签输入均自动聚焦键盘。
- 最新选区修复：布局层现显式记录段间距、段落终止换行、图片附件和零宽保护位等“非正文”范围，以及只用于呈现的文章标题范围。若双击只命中上述任一范围，`ReaderTextView` 会立即清空选区并取消系统待显示菜单；标题与图片任何情况下均不会保留文本选框或文本操作菜单。若拖动从标题、上一段或图片前的正文跨入后续正文，选区会收紧到真实正文，因此可连续覆盖段间距和图片但不会将它们写入锚点或复制文本；不提供图片专属菜单。对应 Reader 布局/选区聚焦测试在 iPhone 16 / iOS 26.5 通过 28/28。
- 关键结论：`PRD.md` 及 `PRD-首轮核心用户路径UX设计.md` 已确认“点击已标注文本 -> 已标注文本就近菜单 -> 打开资产卡片/标签管理”属于当前阅读器与资产卡片范围，不是后续任务。已标注文本打开卡片为查看态；仅进入编辑态时应调起键盘。
- 影响的事实来源：`PRD.md` §1.2/1.3、`PRD-首轮核心用户路径UX设计.md` §3–4；实现位于 `ios_visual_prototype/DeepReadingVisualPrototype/Reader/` 与 `Assets/`。
- 待确认项 / 风险：最新多行划线、锚点、选区与滚动聚焦 XCTest 在 iPhone 16 / iOS 26.5 通过 27/27；运行截图确认既有跨多行资产已逐行完整绘制为 Figma 风格底部划线。仍需用户在模拟器手工验收既有划线的单击菜单、双击划线不会显示普通菜单、普通选区段首手柄、卡片编辑键盘与标签新建键盘的实际触感/视觉位置；当前工作树未提交。
- 下一步：如用户验收中发现菜单定位、键盘上移或卡片视觉与 Figma 仍有差异，继续以 01–08 Frame 为准微调，不扩展至后续模块。
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

### 开发实现 -> 项目集成与决策

- 日期：2026-08-08
- 已完成：Task 1 已完成测试先行实现并提交 `ccb98e9`；Flutter SDK 已通过清华镜像在项目本地 `.tools/flutter` 初始化；格式化、静态分析和完整 Flutter 测试均已在主工作树通过。
- 关键结论：用户已确认 PNG 应分类管理并纳入 Git。PRD 图片迁移至 `docs/assets/prd/`，iOS 图标与启动图保留在 Xcode 资源目录；PNG 忽略规则已移除。
- 影响的事实来源：用户“图片不要提交”指令、Task 1 iOS-only CI 目标、`.gitignore`、`app/ios/Runner/Assets.xcassets/`。
- 待确认项 / 风险：依赖锁文件原先记录国内镜像地址，已成功恢复为 `https://pub.dev`；GitHub Actions 继续使用其默认公共源。无新增跨领域待确认项。
- 下一步：开发实现会话重新审查 Task 1；通过后进入 Task 2。

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
