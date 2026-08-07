# Deep Reading · 首轮核心用户路径技术设计

- 日期：2026-08-07
- 所有者：Tech
- 状态：技术方案已由本技术设计会话确认；涉及跨领域约束的事项待“项目集成与决策”登记。
- 输入事实来源：`PRD.md`、`PRD-首轮核心用户路径UX设计.md`、Figma `UX v1.0 · Design Freeze`、`Intent Recognition and Retrieval Routing Rules.md`、`Output Generation Strategy.md`。

## 1. 范围与非范围

本设计仅覆盖已冻结的首轮核心用户路径：阅读器、文本选择与阅读资产、资产卡片与标签、当前文章汇总、知识库浏览与资产详情、AI 伴读，以及这些模块与后续阅读流之间的导航契约。

不覆盖阅读流页面本身、真实推送/抓取/导入、阅读完成与 AI 阅读报告、完整 AI 搜索 UI 与实现、完整知识库管理例外分支、离线优先同步、正式账号与 App Store 发布。它们只能在本设计中预留边界，不得被作为本轮实现承诺。

求职 Demo 与正式上线共享客户端、数据模型、RPC 和 AI 网关：

- Demo：iOS Simulator `.app` 上传 Appetize；匿名使用；固定种子文章；真实 AI；会话隔离且重开重置。
- 正式上线：在相同架构上补正式认证、内容入库/推送、真机签名、TestFlight 与 App Store 流程。

## 2. 总体架构

```text
Flutter iOS App
  ├─ Riverpod + go_router
  ├─ Drift/SQLite 读取缓存
  ├─ Supabase Auth（匿名 Demo 身份）
  ├─ Supabase Data API（RLS 直接读取）
  ├─ Postgres RPC（受控事务写入）
  └─ Edge Function（AI 网关、预算与限流）
       └─ DeepSeek-V4-Pro（SSE 流）

GitHub 私有仓库 → GitHub Actions macOS Runner
  → iOS Simulator .app → Appetize 单一招聘演示链接
```

客户端采用 Flutter，但首轮只构建、验收、分发 iOS；Android 不属于首轮支持或视觉适配范围。Windows/Android 模拟器只能辅助通用逻辑开发，不能作为 iOS 体验验收依据。iOS 构建使用 GitHub Actions 的 macOS Runner，构建 Simulator `.app`，不需要 Apple Developer 账号、分发证书或 App Store 签名。

## 3. 数据与权限模型

Postgres 是唯一事实来源。预置文章和合集为全局只读种子数据；用户私有数据由 `owner_id = auth.uid()` 实施 RLS 隔离。

| 实体 | 关键字段/约束 |
|---|---|
| `Article` | 不可变文章、标题、元数据、`content_checksum`；首轮不更新或删除。 |
| `ArticleBlock` | `article_id`、稳定排序、`block_id`、正文文本；用于阅读器和锚点。 |
| `ReadingProgress` | `user_id + article_id`、最后阅读块与偏移。 |
| `ReadingAsset` | 统一资产实体，拥有笔记、可选文本锚点、创建时间。 |
| `Tag` / `AssetTag` | 用户标签与资产多对多关系；锁定标签关系单独约束。 |
| `Collection` / `ArticleCollection` | 全局只读合集与文章多对多关系。 |

`ReadingAsset` 的业务形态由字段组合决定：

- `highlight_only`：有锚点、笔记为空；
- `linked_note`：有锚点、笔记非空；
- `standalone_note`：无锚点、笔记非空。

纯划线补写笔记只更新同一资产，不创建副本。创建任何资产时，RPC 自动建立“摘录与思考”锁定关系，用户不能移除该关系。移除普通标签只删除关联；从锁定标签或资产卡片执行删除时，RPC 在同一事务中硬删除资产、全部标签关系、锚点和相关索引。产品不提供回收站或软删除。

## 4. 文本锚点与阅读器

文章推送后不可变，故不实现内容重排后的锚点迁移。划线锚点为：

```text
article_id
start: { block_id, utf16_offset }
end:   { block_id, utf16_offset }
selected_text
content_checksum
```

`utf16_offset` 与 Dart/Flutter 文本选择索引一致；跨段落划线使用不同起止 `block_id`。`selected_text` 和校验值用于异常时的降级展示与诊断，不用于文章迁移。

阅读器正文优先使用 Flutter `SelectionArea`/`SelectableRegion` 与自定义就近菜单。正文控件显现时，顶部与底部遮罩范围不参与选择；控件隐藏时正文选择区域恢复，但 AI 按钮保持更高点击优先级。生产实现使用当前视觉状态动态启用手势，不复制 Figma 中用于原型的透明热区。若 iOS Simulator 验收发现选区手柄、长按或菜单行为无法达到冻结 UX，才以可替换接口局部桥接 Swift 原生选择组件，不嵌入整块原生阅读器。

## 5. 客户端模块与导航

功能模块为 `reading_flow`（仅定义接口）、`reader`、`reading_assets`、`knowledge_base`、`ai_companion`、`shared`。页面级导航使用 `go_router`；Riverpod 管理会话、文章、资产、标签、位置和 AI 流等跨组件业务状态。输入焦点、键盘、选区、卡片动画和菜单显隐属于 Widget 局部状态。

预留且必须遵守的导航契约：

```text
阅读流 → Reader(articleId, origin=feed)
知识库 → Reader(articleId, origin=knowledge)
当前文章汇总 → Reader(articleId, anchorId, origin=feed)
标签详情 → Reader(articleId, anchorId, origin=knowledge)
```

“在文中显示”与标签详情文章标题跳转直接返回指定文章的阅读器并定位锚点；它们不将汇总页压入返回栈。之后左上角返回或 iOS 返回手势回原始入口，不回汇总页。资产卡片、标签 Sheet、样式 Sheet、AI Sheet、确认框和就近菜单均为覆盖态，关闭时恢复打开前的阅读器控件状态和滚动位置。

## 6. 接口边界

- **RLS 直接读**：Flutter 读取种子文章、合集、标签及当前匿名/正式用户的可见资产。
- **Postgres RPC 受控写**：创建或变更资产、纯划线/关联笔记转换、增删标签关系、硬删除、阅读位置更新。每个 RPC 以用户身份执行，保持业务规则原子性。
- **Edge Function**：AI 伴读、Demo 身份滥用控制、会话配额、预算、DeepSeek Key 隔离。敏感服务端 Secret 永不进入 Flutter 包、Appetize 构建物或客户端配置。

## 7. AI 伴读

AI 伴读、难词释义、选中文本解释和菜单“AI 释义”共用一个 Endpoint：

```text
Flutter POST /ai/companion/stream
  → Edge Function 校验身份、限流与预算
  → 按 article_id 从服务端取文章和内容块
  → DeepSeek-V4-Pro chat/completions, stream=true
  → SSE 事件返回 Flutter
```

客户端仅提交文章 ID、问题类型、问题文本和可选选区/锚点。网关自行读取文章正文，忽略客户端提供的文章内容。上下文仅限当前文章：短文传全文；长文传与问题或选区相关的片段和邻近段落；不检索互联网或全局知识库。

Edge Function 统一输出 `started`、`delta`、`completed`、`error`。不向客户端暴露模型思维链。阅读器会话历史只在本次阅读器实例内存中存在；离开阅读器、切换文章或关闭 App 后丢弃，不写入数据库。用户停止生成时中止下游与上游请求，并保留已生成部分。网络失败、429、余额不足或上游错误显示为 AI 消息并支持重试；无法理解的问题显示 AI 说明但不保留该次用户问题。

## 8. 缓存与在线策略

首轮采用在线优先，不实现离线操作队列、冲突合并或本地写入事实源。

- **Drift + SQLite**：文章正文、文章元数据、最近页面快照、缓存版本和过期时间；先读缓存立即展示，再刷新 Supabase，成功后覆盖缓存。
- **SharedPreferencesAsync**：字号、主题等非关键轻量偏好；不保存资产或认证数据。
- **flutter_cache_manager**：文章缩略图等网络文件的磁盘缓存与过期清理。

资产写入始终经过 Supabase RPC。已加载文章可由缓存继续展示；资产写入和 AI 伴读要求网络可用。

## 9. Demo 身份、滥用控制与隐私

Demo 启动时静默调用 Supabase 匿名登录。匿名身份使用 RLS 访问自己的阅读资产与标签数据；每位访问者的数据隔离，重开 Demo 后从同一种子内容开始。启用 CAPTCHA/Turnstile、身份创建限速、匿名账户 TTL 清理、AI 会话级限流、单次最大输出和全局日/周预算。

日志只记录匿名请求 ID、RPC/AI 错误码、耗时、Token 用量和预算事件；不得记录完整文章正文、用户问题或笔记。正式上线前需由项目集成与决策补充数据处理与用户告知要求。

## 10. 构建、发布与测试

GitHub 私有仓库保存代码与 GitHub Actions 工作流。常规提交在可用 Runner 上执行格式检查、静态分析、Dart 单元测试和 Flutter Widget 测试；手动 Demo 发布或 Demo 标签触发 macOS Runner：构建 iOS Simulator `.app`、压缩、上传 Appetize，并将构建号和提交 SHA 关联到同一稳定演示链接。

测试范围：

1. 单元测试：资产形态转换、锚点、标签关系、硬删除、AI 上下文组装；
2. Widget 测试：控件显隐、卡片/Sheet、汇总跳转、AI 流式和错误态；
3. iOS Simulator/Appetize 走查：按首轮用户路径验证文本选择、资产、标签、知识库、AI 取消与重试。

## 11. 风险与后续边界

- Flutter 与冻结 iOS 文本选择体验可能存在差异；以 iOS Simulator 作为唯一体验验收，必要时局部 Swift 桥接。
- Appetize 与本地 iOS Simulator 的交互和网络行为可能不同；发布前两处均需走查。
- 公开 Demo 的真实 AI 会产生费用；预算、限流与停用开关必须优先实现。
- Supabase Edge Function 的流式时长有限；必须限制最大输出并正确处理上游中断。
- 正式账户、跨设备同步、离线编辑、内容推送、AI 搜索和阅读报告为后续独立技术/产品范围，不能通过首轮临时代码默认实现。

