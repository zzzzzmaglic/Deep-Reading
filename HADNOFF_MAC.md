# Mac 本机验收与视觉重建交接日志

> 本文档记录 Mac 本机 iOS Simulator 验收环境、视觉重建工作及其交接输入。正式产品、UX 与技术规则仍以 `docs/PROJECT_STATE.md` 所列事实来源为准；冻结 Figma 文件是视觉交付的唯一事实来源。

## 当前交接

### 资产卡片空笔记占位与编辑光标定位 -> 用户手工验收

- 日期：2026-08-23
- 已完成：关联型笔记查看态的“添加笔记内容”按钮不再位于笔记区域中部，现复用笔记文本容器第一行的 `308 pt / x=18.5 / y=116 pt` 几何。关联型与独立型笔记从查看态进入编辑态时，已有笔记的光标会仅在切换瞬间移动至现有文本末尾；编辑过程不会反复改写光标位置。已完整移除引用内容的临时青色文本容器边框。
- 验证：占位位置与光标末尾范围测试先以缺少实现红灯失败；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 27/27 通过，Debug build、安装与启动通过。未提交、未推送。
- 待确认项 / 风险：请用户分别验证空关联型卡片的占位位置，以及含文本的关联型/独立型卡片“查看→编辑”后光标在内容末尾。既有 `UIScreen.main` 弃用警告未在本轮扩大范围处理。
- 下一步：等待用户继续手工验收反馈。

### 关联型笔记引用上移与笔记两端对齐 -> 用户手工验收

- 日期：2026-08-23
- 已完成：关联型笔记查看态与编辑态的引用文字容器均由 `y=26 pt` 上移至 `y=25 pt`，宽度与居中位置保持 `294 pt / x=25.5 pt` 不变。关联型笔记的笔记 `UITextView` 在查看态与编辑态均使用原生 `NSTextAlignment.justified` 两端对齐；独立型笔记仍使用左对齐。切换状态时会重新应用段落属性，避免保留上一个状态的对齐方式。
- 验证：布局与两端对齐用例先以缺少对齐选择函数和旧 `y=26 pt` 红灯失败；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 26/26 通过，Debug build、安装与启动通过。未提交、未推送。
- 待确认项 / 风险：引用容器的青色边界仍是临时手工验收辅助；既有 `UIScreen.main` 弃用警告未在本轮扩大范围处理。
- 下一步：用户在 Simulator 中比较关联型笔记查看态与编辑态，确认引用上移、笔记两端对齐及状态切换时的排版一致。

### 关联型笔记查看态与编辑态文本容器对齐 -> 用户手工验收

- 日期：2026-08-23
- 已完成：关联型笔记查看态、既有编辑态和新建关联草稿的引用容器现统一为 `294×76 pt / x=25.5 pt`，居中于 345 pt 卡片；编辑态引用容器从原 `y=24` 下移至 `y=26 pt`。关联型笔记的笔记容器在查看态和编辑态现统一为 `308×220 pt / x=18.5 / y=116 pt`，因此两态的引用、笔记容器位置一致。引用灰底、卡片高度与独立型笔记未调整。
- 验证：布局回归用例先以 4 项几何断言红灯（旧 `290/302` 宽度及旧位置）；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 25/25 通过，Debug build、安装与启动通过。未提交、未推送。
- 待确认项 / 风险：引用容器的青色边界仍是临时手工验收辅助，确认完成后应按用户指示移除；既有 `UIScreen.main` 弃用警告未在本轮扩大范围处理。
- 下一步：用户在 Simulator 中比较关联型笔记的查看态与编辑态，核对引用框、笔记框的宽度和位置一致。

### 关联型笔记引用容器三态统一 -> 用户手工验收

- 日期：2026-08-22
- 已完成：关联型笔记的引用文字容器统一为 `290×76 pt / x=27.5 pt`，保持在 345 pt 卡片内居中。查看态保留其原有 `y=22 pt`，编辑态保留其原有 `y=24 pt`；两态宽度一致。新建带文本选区的关联型笔记不再回退到旧 `296 pt` 宽度，直接走同一编辑态容器规则。引用灰底、笔记输入区和其他资产类型均未调整。
- 验证：更新查看态、既有编辑态与新建关联草稿三条路径的布局断言，先以缺失选择逻辑红灯失败；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 25/25 通过，Debug build、安装与启动通过。未提交、未推送。
- 待确认项 / 风险：引用容器的青色边界仍是临时手工验收辅助；确认宽度后应按用户指示移除。
- 下一步：用户在 Simulator 中分别打开已有的关联型笔记查看态/编辑态，以及新建文本选区后的卡片编辑态，核对三者引用内容每行字数与居中位置。

### 引用容器可视化覆盖范围修正 -> 用户手工验收

- 日期：2026-08-22
- 已完成：修正引用容器验收边框的触发条件。此前只覆盖“已保存且已经是关联型笔记”的编辑态，纯划线与刚由选区打开的关联草稿会被错误排除；现改为任何含引用内容的卡片处于编辑态都显示该引用 `Text` 自身的 1 pt 青色边界。各卡片仍使用其原有的真实文本布局，未调整卡片内容或灰底。
- 验证：新增覆盖范围回归断言先以缺少条件函数红灯失败；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 24/24 通过，Debug build、安装与启动通过。未提交、未推送。
- 待确认项 / 风险：边界为临时手工验收辅助，确认几何后应按用户指示移除。
- 下一步：用户在 Simulator 中从任一文本选区打开资产卡片，进入编辑态后核对引用区域青色边界。

### 关联型笔记编辑态引用容器可视化 -> 用户手工验收

- 日期：2026-08-22
- 已完成：仅在既有关联型笔记的编辑态，为实际承载引用内容的 SwiftUI `Text` 视图自身显示 1 pt 青色边界。边界直接附着在既有 `284×76 pt / x=30.5 / y=24` 文本布局上，不创建第二个估算框，不改变灰底、文字排版、命中区域或其他卡片状态。
- 验证：新增回归用例先以缺少引用容器可视化开关红灯失败；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 24/24 通过，Debug build、安装、启动与 `git diff --check` 通过。未提交、未推送。
- 待确认项 / 风险：该边界是临时手工验收辅助，确认几何后应在下一轮用户指示下移除；既有 `UIScreen.main` 弃用与 Assets 图集警告未处理。
- 下一步：用户在 Simulator 中打开一个既有的关联型笔记并进入编辑态，核对青色边界与引用内容的实际可用宽度。

### 关联型笔记编辑态引用框二次缩窄 -> 用户手工验收

- 日期：2026-08-22
- 已完成：仅将既有关联型笔记的编辑态引用文字框再缩窄 6 pt：由 `290 pt` 调整为 `284 pt`，并以 `x=30.5 pt` 保持在 345 pt 卡片内水平居中。引用文字框仍位于 `y=24 pt`；引用灰底仍为 `x=11 / y=11 / 323×93 pt`，关联型笔记编辑输入区仍为 `x=19 / y=116 / 302 pt`。查看态、纯划线编辑态与独立型笔记均未调整。
- 验证：先将几何回归断言更新为 `284 pt / x=30.5 pt`，确认旧实现红灯失败；最小调整后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 23/23 通过，`xcodebuild build` 通过。未提交、未推送。
- 待确认项 / 风险：请用户核对既有关联型笔记的编辑态，确认引用第一行较之前少容纳一个汉字；既有 `UIScreen.main` 弃用与 Assets 图集警告未处理。
- 下一步：等待用户继续手工验收反馈。

### 关联型笔记编辑态局部文本几何 -> 用户手工验收

- 日期：2026-08-22
- 已完成：按用户最新验收要求，仅调整已存在关联型笔记的编辑态：引用文字框由 296 pt 缩至 290 pt，并以 `x=27.5 pt` 保持在 345 pt 卡片内水平居中；引用文字框自 `y=22` 下移至 `y=24`。引用灰底仍保持 `x=11 / y=11 / 323×93 pt`，未移动。关联型笔记编辑输入区仍为 302 pt 宽、高度不变，自 `y=114` 下移至 `y=116`。查看态、纯划线编辑态及独立型笔记均未调整。
- 验证：新增几何回归测试先以缺少编辑态布局常量红灯失败；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 23/23 通过。Debug build 成功并已重装、启动到同一 iPhone 16 Simulator；未提交、未推送。
- 待确认项 / 风险：请用户仅核对“既有关联型笔记 → 编辑”路径的引用/笔记视觉位置。既有 `UIScreen.main` 弃用与 Assets 图集警告未处理。
- 下一步：等待用户继续手工验收反馈。

### 阅读资产卡片 06c 文字与两态布局 -> 用户手工验收

- 日期：2026-08-22
- 已完成：已通过 Figma MCP 精确读取 `06c 阅读资产卡片 · 编辑态有未保存修改（键盘）`（`618:1061`）。关联型卡片的引用底板现按其本地卡片坐标改为 `x=11 / y=11 / 323×93 pt`，引用文字为 `x=25 / y=22 / 296×76 pt`；所有关联型与独立型卡片正文均为 14 pt。引用为 24 pt 固定行高，笔记为 20 pt 固定行高。关联型笔记的查看与编辑状态现共用一个无边框 UIKit 文本视口、同一 `x=19 / y=114 / 302 pt` 几何和同一固定行高，不再分别以 SwiftUI `Text` 与 `TextEditor` 渲染，避免切换时内边距、字距或高度漂移。
- 验证：新增 Figma 06c 几何与字体回归断言先以缺少新布局常量红灯失败；最小实现后，iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 22/22 通过。随后 `xcodebuild build` 通过、`git diff --check` 通过；更新后的 Debug App 已重新安装并启动到同一 iPhone 16 Simulator。构建仍保留既有 `UIScreen.main` 弃用与 Assets 图集未分配子项警告，未在本轮扩大范围处理。
- 待确认项 / 风险：请用户打开一个含笔记的关联型卡片，依次查看态 → 编辑态，确认引用与笔记的视觉位置、尺寸和行距保持不跳动；并确认引用灰底已接近卡片边缘。未提交、未推送；工作树仍包含此前阶段 C–F 的未提交改动。
- 下一步：等待用户手工验收反馈后再做局部视觉调整。

### 原生迁移阶段 F 真实 UI 验证 -> 用户手工验收

- 日期：2026-08-20
- 已完成：已用临时 `.xctestrun` 将本机 Supabase 的公开配置分别注入 UI Test runner 与被测 App，真实 iPhone 16 UI 流程已通过：阅读器 → 当前文章汇总 → `在文中显示` → 同一阅读器。验证过程中发现并修复两项测试路径问题：测试划线异步创建完成前过早打开汇总页，以及汇总资产行的最外层可访问性标识吞掉 `在文中显示` 子按钮。正常用户启动不受测试等待逻辑影响。
- 验证：iPhone 16 / iOS 26.5 ARM64，`Task6To9FlowUITests.testReaderAssetSummaryReturnsToAnchoredReader` 通过（`xcodebuild test-without-building` exit 0）；`ArticleAssetSummaryCoordinatorTests` 聚焦 XCTest 通过（`xcodebuild test` exit 0）；`git diff --check` 通过。本机 Supabase 核心服务可用；imgproxy 与 pooler 停止，但本轮不依赖它们。
- 安全与工作区：临时 `.xctestrun` 在测试结束后自动删除，公开配置未写入项目或 Git；测试仅在本机匿名用户下新增划线，不连接远端或生产数据。工作树仍含阶段 C–F 的未提交改动；未提交、未推送。
- 待确认项 / 风险：仍需用户在 Simulator 手工验收汇总卡片、右滑多选与删除的视觉和触感。构建保留既有 `UIScreen.main` iOS 26 弃用、资产图集未分配子项等警告，未在本轮扩大范围处理。
- 下一步：等待用户对 Task F 汇总页的手工验收反馈；不要扩展至 Task 10+。

### 阅读资产卡片引用文本 -> 用户手工验收

- 日期：2026-08-20
- 已完成：阅读资产卡片的引用区现直接显示保存的原文选区，不再额外包裹中文左、右引号；不改变选区保存值、划线、标签、笔记或卡片尺寸。
- 验证：TDD 红灯为 `ReadingAssetCard.quoteDisplayText` 不存在；最小实现后 iPhone 16 / iOS 26.5 ARM64 `AssetDraftControllerTests` 18/18 通过。Debug App 已重装并启动，进程仍在运行。
- 待确认项 / 风险：请用户打开任一关联型阅读资产卡片，确认引用区不出现装饰引号。既有 iOS 26 `UIScreen.main` 弃用警告未在本轮处理。
- 下一步：等待用户继续验收反馈；未提交或推送。

### 系统保底标签 -> 用户手工验收

- 日期：2026-08-20
- 已完成：已将 `202608190001_system_tag_invariant.sql` 和兼容迁移 `202608200001_make_asset_tag_rpcs_idempotent.sql` 应用于当前 Mac 本地 Supabase，未重置或清除既有验收数据。后者使两个既有“新建独立笔记并关联标签”RPC 与资产自动关联系统标签的触发器兼容，避免同一 `(asset_id, tag_id)` 重复插入。
- 关键结论：每个匿名或正式用户的“摘录与思考”都由数据库在用户创建时自动提供并锁定；任意新阅读资产都会由数据库自动关联该标签。客户端只负责将系统标签排在普通标签前并锁定选中，不再要求首次创建资产前标签已存在。
- 验证：完整 pgTAP 已通过（7 个文件、83 项、0 失败）；iPhone 16 / iOS 26.5 ARM64 完整 XCTest 已通过（113 通过、2 个配置跳过、0 失败）。Debug App 已重建、安装并启动到本机 iPhone 16，当前停在阅读器首页；未提交或推送。
- 待确认项 / 风险：请用户在阅读器创建或打开任意资产卡片，点 `#标签`，确认“摘录与思考”位于最上方、锁定且已选中；对新建划线或非空独立笔记确认资产自动带有该标签。当前青绿色文字行框为既有排版验收辅助，不属于此项修改。
- 下一步：仅根据手工验收的具体现象处理；确认后再决定是否提交当前工作树已有的阶段 C–F 改动。

### 系统保底标签不显示 -> 后续验收

- 日期：2026-08-19
- 已完成：修复“摘录与思考”在新匿名用户的标签页中缺席，以及首次创建资产会被客户端 `missingSystemTag` 提前拦截的问题。新增 Supabase 迁移：认证用户创建后自动拥有该系统标签、既有用户自动回填、任意新阅读资产自动关联、历史资产补齐关联；Swift 客户端不再在创建 RPC 前要求标签预先存在，并固定将系统标签排在普通标签之前、保持锁定选中。
- 关键结论：PRD 的系统保底标签规则现在由数据库不变量承载，而非依赖用户创建或某个特定客户端流程。创建划线/独立笔记 RPC 仍保留原有幂等保障，数据库资产触发器作为最终兜底。
- 验证：TDD 红灯已记录——Swift 首次划线测试以 `missingSystemTag` 失败、pgTAP 4/4 失败；Swift 修复后聚焦 2/2、资产与标签套件 24/24、完整单元测试 114 executed / 1 expected skip / 0 failed。新增 pgTAP 文件 `007_system_tag_invariant.test.sql`。
- 待确认项 / 风险：Codex 自动授权额度限制拒绝了 `supabase migration up --local`，因此新增迁移尚未应用到当前正在运行的本地数据库，pgTAP 绿灯也尚未取得；这不是 SQL/Supabase 执行错误。不得声称当前 Simulator 已看到修复后的标签。
- 下一步：授权恢复后在仓库根目录执行 `supabase migration up --local`（或验收允许时 `supabase db reset`），随后执行 `supabase test db`，重建并启动 App，确认标签 Sheet 顶部显示锁定选中的“摘录与思考”。

### 阅读资产空内容确认语义 -> 后续验收

- 日期：2026-08-19
- 已完成：修正阅读资产卡片编辑态的空内容确认分支。有文本锚点时，空白笔记确认会创建并保存纯划线资产后关闭卡片；无文本锚点的独立型笔记草稿为空时，确认不会创建任何资产，直接关闭，行为与空卡片点击外部一致。独立型笔记非空保存、关联型笔记保存、标签与删除流程保持不变。
- 关键结论：原根因是 `AssetDraftController.save()` 在所有“尚无 assetID”的草稿上统一执行非空笔记校验，没有先区分 `anchor` 是否存在。现按 `asset / anchor / standalone` 三种业务形态分流；新建纯划线仍经过真实 `createHighlight` 与 `saveReadingAsset(noteContent: nil)`，因此保留系统标签和用户暂存标签。
- 验证：新增两个 TDD 回归用例，先确认均以 `emptyStandaloneNote` 红灯失败；修复后聚焦 2/2、`AssetDraftControllerTests` 16/16、完整单元测试 112 executed / 1 expected skip / 0 failed；iPhone 16 / iOS 26.5 ARM64 Debug build 成功，已安装并启动到 Simulator；`git diff --check` 通过。
- 待确认项 / 风险：尚未由用户手工点击两种空内容确认路径；此前暂停的“确认弹窗出现时保持键盘状态”问题未包含在本次改动中。
- 下一步：用户在 Simulator 分别验收“选区→打开资产卡片→空笔记确认”和“独立型笔记→空内容确认”。

### 原生迁移阶段 F -> 主会话验证

- 日期：2026-08-19
- 已完成：当前文章“标注与笔记”汇总已增量实现并完成独立复审。纯划线/关联型笔记按正文 block 与 UTF-16 起点排序，独立笔记置底并按创建时间倒序；阅读器入口、同一根 `NavigationStack`、普通返回、`在文中显示`替换原阅读器 route、来源返回合约及阅读器资产刷新 revision 已接通。汇总支持复用阅读资产卡片、右滑多选、不可恢复删除确认；单项 RPC 批次在部分成功后记录已完成 ID，重试只继续剩余项，并以单飞防止重复删除。UI Test target、依赖、配置和 shared scheme 已完整注册。
- 关键结论：实现遵循冻结 Figma 09/09a/09b/10/11/11a（393×852、`#F2F2F7`、116 pt 顶部渐进虚化、371 pt/18 pt 卡片、8 pt 间距、4×23 pt 强调色条、灰色多选与底部删除层）及 PRD §1.6/UX §5；复用既有 progressive blur、Liquid Glass 与 `ReadingAssetCard`。未实现 Task 10+、AI 或发布功能。Figma 精确参数直接影响了汇总卡片、顶部固定层、底部删除层与确认态的实现。
- 验证：iPhone 16 / iOS 26.5 ARM64 上，Stage F 协调器聚焦 XCTest 7/7 通过；完整单元测试 110 executed、1 expected skip、0 failed；UI target 实际构建并在缺少公开环境变量时 1/1 explicit skip、0 failed；Debug Simulator build 成功；`git diff --check`、`plutil -lint project.pbxproj`、scheme XML 校验通过。测试修正了旧用例依赖绝对 TextKit 位置的问题，现按真实 block range 验证 350 ms 进度节流。
- 待确认项 / 风险：带真实本地 Supabase 公共变量的端到端 UI 流程与关键状态截图尚未完成；读取本地公开环境的受控命令被 Codex 自动审批系统以当前用量额度耗尽拒绝，并非项目或 Supabase 报错。共享工作树仍包含阶段 D–E 及此前暂停的键盘/确认弹窗改动，未 reset/revert；`supabase/.branches/` 与 `supabase/.temp/` 未纳入项目改动。
- 下一步：审批额度恢复后，以不输出凭据的方式运行 `DeepReadingVisualPrototypeUITests/Task6To9FlowUITests` 的真实本地 Supabase 路径，捕获 reader/card/summary/anchor-return 截图；随后由用户在 iPhone 16 Simulator 手工验收。确认态保持键盘的问题仍按用户要求暂停，不计入 Stage F。

### Mac 本机验收环境 -> 用户手工验收

- 日期：2026-08-14
- 已完成：iPhone 16（iOS 26.5）上的 Deep Reading Debug App 已全新安装并停在 `Deep Reading QA` 启动页；`Open seed article` 按钮可见，未由 Codex 点击。Mac 本地 Supabase 已完成 `db reset` 并恢复健康。
- 关键结论：首次启动白屏由本地 Supabase Auth 在匿名注册时连接数据库超时并返回 HTTP 500 所致，不是 Flutter 构建或 Simulator 故障。重新初始化本机数据库、种子数据并全新安装 App 后，匿名登录正常完成。
- 影响的事实来源：当前 Git HEAD `130f1c0`；本机 API 地址 `http://127.0.0.1:54321`；Flutter 3.47.0 stable；iPhone 16 iOS 26.5。
- 待确认项 / 风险：视觉重建仍只完成阅读器基础层，05–08 覆盖态尚未实现；QA 首页是 Debug 专用入口，不对应 Figma 产品页。
- 下一步：等待用户亲自点击 `Open seed article` 开始验收；仅在用户报告具体现象、操作问题或报错后继续排查。

### Mac 本机验收 / 视觉重建 -> 后续实现与验收

- 日期：2026-08-14
- 已完成：已完成阅读器视觉基础层及原生 iOS 玻璃控件桥接的测试先行实现：暖白正文、Figma 顶/底渐进虚化、44 pt 玻璃控件位置、常驻但禁用的 AI 入口、Figma 导出的独立型笔记 SVG。Flutter 阅读器 Widget 回归 10/10 通过；Runner XCTest 在 iOS 26.5 上确认 `UIGlassEffect` 生效。
- 关键结论：`flutter analyze` 在项目真实中文路径下会在分析服务器初始化时崩溃，错误为 `FormatException: Unterminated string`；同一 SDK 在全新 ASCII 路径模板和当前代码的 ASCII 临时镜像均显示 `No issues found`，确认是路径环境缺陷而非代码分析错误。后续静态分析继续使用一次性 ASCII 镜像，原项目路径不作规避性改名或移动。
- 影响的事实来源：Figma `6:2` 及 `66:23`；后者确认 05 阅读资产查看态的卡片实际为 x=24、y=196、345 × 460 pt、28 pt 顶角，替代此前 371 pt 的误记。
- 待确认项 / 风险：05–08 的卡片、编辑态、删除确认与标签 Sheet 尚未重建；AI 按钮只为本轮视觉入口，不接入 Task 11 的 Sheet 或业务。
- 下一步：为 05–08 写基于 345 × 460 pt 的失败 Widget 测试，按 Figma 重建覆盖层与标签 Sheet；随后在 iPhone 16 iOS 26.5 运行 Debug App 截图比对。

### Mac 本机验收 / 视觉重建 -> 后续实现与验收

- 日期：2026-08-14
- 已完成：用户已确认采用混合实现：Flutter 持有阅读器内容与交互状态，iOS 原生控件层使用 Apple 官方 Liquid Glass；本轮范围已收敛为 Figma 01–08 的阅读器及其覆盖态。
- 关键结论：SF Symbols 必须原生调用，Liquid Glass 必须使用 iOS 官方动态材质 API，不作为 Figma 图片导出；仅自定义 AI 双眼图标使用 Figma SVG 资产。iPhone 16（393 × 852 pt、iOS 26.5）是静态截图基准。
- 影响的事实来源：`docs/superpowers/specs/2026-08-14-reader-visual-reconstruction-design.md`、冻结 UX 文档第 2、3、4、7、10 节和 Figma `UX v1.0 · 开发交付` 01–08。
- 待确认项 / 风险：需由用户复核设计文档后才能写实施计划；iOS 26 以下仅提供视觉/功能回退，不承诺真正 Liquid Glass。
- 下一步：用户确认设计文档后，编写可逐任务执行的 TDD 实施计划；随后在 iPhone 16 iOS 26.5 完成截图叠图验证。

### Mac 本机验收 / 视觉重建 -> 后续实现与验收

- 日期：2026-08-14
- 已完成：已克隆并检出 `feature/first-core-user-path`，当前 HEAD 为 `130f1c0 test: add debug reader QA entry`。Mac 本地 Docker Desktop、Supabase CLI 与 Flutter stable 已准备；`supabase start`、`supabase db reset` 已在本机完成，种子数据已载入。iPhone 17 Pro（iOS 26.5）曾成功构建并运行 Debug App。
- 关键结论：`Deep Reading QA` 与 `Open seed article` 是仅 Debug 模式下的验收入口，不是 Figma 产品页面。阅读器实现的功能路径可运行，但视觉层未按冻结 Figma 的 `01 阅读器 · 控件显现态`（节点 `6:2`）还原：当前使用普通 Material `IconButton` 与默认布局，缺少 Figma 指定的米白背景、顶部/底部虚化、44pt Liquid Glass 控件、底部玻璃工具组及 AI 入口等。
- 影响的事实来源：Figma `Deep Reading · iOS MVP UX Prototype`，`UX v1.0 · 开发交付` 中阅读器节点 `6:2`、`20:2`、`23:2`、`33:2` 及后续资产卡片节点；`app/lib/features/reader/presentation/reader_screen.dart` 与 `reader_style_sheet.dart`。
- 环境与工作区状态：本地 Supabase API 为 `http://127.0.0.1:54321`，仅使用 anon/publishable 客户端配置，不记录或传递 service-role、Storage secret 或 DeepSeek 密钥。为本机运行，Flutter 自动修改了 `app/pubspec.lock`、`app/analysis_options.yaml` 与 `app/ios/Runner.xcodeproj/project.pbxproj`；Supabase 生成了 `supabase/.branches/` 与 `supabase/.temp/`。这些改动尚未提交。
- 待确认项 / 风险：视觉重建应以 iPhone 16（iOS 26.5）为基准尺寸；需先确定验收标准是“逐像素对齐冻结 Figma 静态态”，还是“视觉与交互语义对齐并保留原生动态类型/系统差异”。Figma 中的 Liquid Glass 为 iOS 26 组件，需要决定采用可复用 Flutter 近似组件、原生 SwiftUI/UIKit 平台视图，或混合方案。
- 下一步：关闭 iPhone 17 Pro Simulator，创建 iPhone 16（iOS 26.5）作为视觉基准；完成阅读器视觉层设计与实施计划后，先重建控件显现态与专注阅读态，再在该设备上逐帧对比 Figma 节点 `6:2` 与 `20:2`，随后扩展到文本选择、划线与阅读资产卡片状态。

## 追加模板

每次产生实质进展、风险、冲突或待处理事项时，在“当前交接”顶部追加一条记录：

```md
### [来源角色] -> [目标角色]

- 日期：YYYY-MM-DD
- 已完成：
- 关键结论：
- 影响的事实来源：
- 待确认项 / 风险：
- 下一步：
```
