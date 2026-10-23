# 项目状态与决策记录

> 本文档是跨 session 的状态索引与跨领域决策台账，不替代 PRD、UX、Figma 或技术设计文档。
>
> 最后更新：2026-10-23

## 当前阶段

首轮核心用户路径已进入持续实现和 Simulator 验收阶段。阅读器、文本标注与阅读资产、资产卡片与标签、当前文章汇总、知识库浏览与资产详情已具备可运行的原生 iOS Demo；完成阅读、AI 阅读报告和 AI 伴读也已按后续用户确认纳入并完成当前 Demo 实现。

完整知识库 AI 搜索、正式上线认证/隐私/配额策略及生产发布能力仍属于后续范围。这不表示整个软件或全部 MVP 模块的 UX 与原型设计已完成。

## 工作流状态

| 工作流 | 角色 / Session | 当前状态 | 当前产出与下一步 |
| --- | --- | --- | --- |
| 产品规则与项目整合 | 项目集成与决策（Main / Integration，原“PRD设计”） | 进行中 | 已确认首轮技术设计与实现范围；负责审阅实施计划、维护正式决策并处理跨领域问题。 |
| UX 与 Figma 原型 | Prototype / Design（“UI/UX设计、Figma原型设计”） | 首轮设计已冻结 | 已完成首轮核心用户路径 UX 设计、静态页面稿与可点击原型；在已确认规则与设计范围内，可独立完成 UX/Figma 高频迭代，并在后续轮次继续设计未覆盖模块。 |
| 技术设计 | Tech（“技术设计”） | 已确认 | 首轮核心用户路径技术设计已收敛；后续模块按新增设计范围启动独立技术设计。 |
| 开发计划 | Main / Integration | 已完成 | [首轮核心用户路径实施计划](superpowers/plans/2026-08-07-first-core-user-path.md) 已完成，并已明确范围与测试顺序。 |
| 开发实现与验收 | Implementation / QA | 进行中 | 原生 iOS Demo 已覆盖核心阅读链路、阅读报告与 AI 伴读；继续进行 Simulator 手工验收与局部修正。 |

## 各领域事实来源

| 领域 | 唯一事实来源 |
| --- | --- |
| 产品规则 | [PRD.md](../PRD.md) |
| UX 规则与开发交付信息 | [PRD-首轮核心用户路径UX设计.md](../PRD-首轮核心用户路径UX设计.md) |
| Figma 原型 | [Deep Reading · iOS MVP UX Prototype](https://www.figma.com/design/AlP0sHIcwynu6Oi7Hwt9u8/Deep-Reading-%C2%B7-iOS-MVP-UX-Prototype?node-id=0-1) |
| AI 搜索意图与检索路由 | [Intent Recognition and Retrieval Routing Rules.md](../Intent%20Recognition%20and%20Retrieval%20Routing%20Rules.md) |
| AI 搜索输出策略 | [Output Generation Strategy.md](../Output%20Generation%20Strategy.md) |
| 技术约束与接口 | [2026-08-07-deep-reading-core-path-technical-design.md](superpowers/specs/2026-08-07-deep-reading-core-path-technical-design.md) |
| 首轮实现计划 | [2026-08-07-first-core-user-path.md](superpowers/plans/2026-08-07-first-core-user-path.md) |

## 已确认跨领域决策

| 日期 | 决策 | 影响工作流 | 状态 |
| --- | --- | --- | --- |
| 2026-08-01 | 首轮核心用户路径 UX 设计已冻结为 `UX v1.0 · Design Freeze`；Figma 本地副本为 `Deep Reading · iOS MVP UX Prototype_v1.0_Design Freeze.fig`。该冻结不涵盖整个软件的全部模块。 | 首轮 UX、对应技术设计、开发、验收 | 已确认 |
| 2026-08-02 | 阅读资产统一建模为 `ReadingAsset`；纯划线、关联型笔记、独立型笔记为同一实体的三种业务形态。 | PRD、UX、技术设计、AI 搜索、开发 | 已确认 |
| 2026-08-02 | 以多个 session 分担探索与执行；项目文件为唯一同步层。Main / Integration 负责跨领域决策确认。 | 全部工作流 | 已确认 |
| 2026-08-07 | 首轮客户端采用 Flutter，但仅构建、分发与验收 iOS；Android 不属于本轮支持或视觉验收范围。 | 技术设计、UX 验收、开发计划、测试 | 已确认 |
| 2026-08-07 | 首轮后端采用 Supabase：匿名 Auth + RLS 隔离、Postgres RPC 受控写入、Edge Function 作为 AI 网关；AI 伴读使用 DeepSeek-V4-Pro 的 SSE 流式输出。 | 技术设计、AI 伴读、数据与隐私、开发计划 | 已确认 |
| 2026-08-07 | 求职 Demo 采用固定种子文章与匿名隔离身份；GitHub Actions macOS Runner 构建 iOS Simulator `.app` 并上传 Appetize，提供单一演示链接。 | Demo 交付、CI/CD、测试 | 已确认 |
| 2026-08-07 | 首轮采用在线优先：Drift/SQLite 仅作读取缓存；不实现离线编辑、同步队列、冲突合并或本地写入事实源。 | 数据模型、客户端、错误处理、开发计划 | 已确认 |
| 2026-08-07 | 本次实现计划不包含阅读流、完成阅读与 AI 阅读报告、完整知识库 AI 搜索及正式上线能力；它们保留为后续范围。 | 开发计划、后续 UX 与技术设计 | 已确认 |
| 2026-10-23 | 用户后续明确扩展 Demo 范围，完成阅读、AI 阅读报告与 AI 伴读已进入原生 iOS Demo；AI 伴读和阅读报告固定使用 `deepseek-flash`，任何情况下不使用或回退 Pro。AI 伴读麦克风仅保留视觉，当前 Demo 不实现语音识别或动态快捷问题。 | AI、原生 iOS Demo、验收 | 已确认（覆盖 2026-08-07 对上述模块的阶段性范围与模型选择） |

## 当前待确认事项

- 正式上线阶段的认证方式、数据处理与用户告知、Supabase 部署区域及服务计划。
- Apple Developer 账号、真机签名、内容入库/推送、TestFlight 与 App Store 分发方案。
- 阅读流、完成阅读与 AI 阅读报告、完整知识库 AI 搜索及其他未纳入首轮实现范围模块的后续 UX 与技术设计。

## 使用规则

- 新 session 启动时，先阅读本文件、`HANDOFF.md` 与其工作流对应的事实来源。
- 只有“项目集成与决策” session 可以将跨领域提议标记为“已确认”。
- 其他 session 应将新结论记录为提议、风险或待确认项，并在 `HANDOFF.md` 中通知相关工作流。
