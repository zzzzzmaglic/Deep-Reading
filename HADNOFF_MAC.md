# Mac 本机验收与视觉重建交接日志

> 本文档记录 Mac 本机 iOS Simulator 验收环境、视觉重建工作及其交接输入。正式产品、UX 与技术规则仍以 `docs/PROJECT_STATE.md` 所列事实来源为准；冻结 Figma 文件是视觉交付的唯一事实来源。

## 当前交接

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
