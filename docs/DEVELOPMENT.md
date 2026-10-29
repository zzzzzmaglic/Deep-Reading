# AI Coding 开发实践

本项目以产品需求和 Figma 交互稿为输入，通过 AI Coding 实现原生客户端与后端，再以模拟器操作、测试和日志验证迭代结果。这里记录可从源码追溯的开发案例。

## 将交互拆解为可复用的数据与状态

阅读过程中的纯划线、关联型笔记和独立型笔记统一为阅读资产。查看、编辑、未保存退出、标签选择和原文跳转需要在多个页面保持一致，因此由数据模型、卡片状态和页面 Coordinator 共同管理，而非为每个入口单独实现一套行为。

对应代码：`Reader/`、`Assets/`、`Knowledge/`，及 `DeepReadingVisualPrototypeTests/` 中相关资产与 Coordinator 测试。

## 将模型输出组织为可检查的生成管线

阅读报告分为认知分析与报告写作两次调用。先选择最长有效笔记，再校验分析 JSON，随后按组件组装写作提示词。分析协议失败时重试一次；提示词源 Markdown 通过脚本同步为运行时内容，支持本地导出最终组合提示词，便于检查实际传入模型的内容。

对应代码：`supabase/functions/reading-report/pipeline.ts`、`index.ts`、`pipeline_test.ts`，以及 `supabase/scripts/`。

## 用运行证据定位环境问题

无签名 Release 模拟器曾出现匿名登录返回成功、首页却提示无法连接服务的情况。通过同包本地复现和定向日志，确认 Keychain 返回 `-34018`，SDK 无法保存会话。最终为 Release simulator 提供内存 Auth 存储，并在后续数据初始化前检查会话是否可读取。

对应代码：`Data/SupabaseClientFactory.swift`、`Data/AppSessionStore.swift`；完整历史记录见 `docs/HANDOFF.md`。

## 验证方式

- XCTest 验证客户端模型、状态和布局行为；UI 测试验证部分跨页路径。
- pgTAP 验证数据库权限隔离与 RPC 行为。
- Deno 测试验证 AI 请求、协议与管线逻辑。
- 模拟器验收核对系统控件、文本排版、键盘及滚动交互。

以上为验证方式与代码入口，不代表每一项测试在当前提交上均已重新通过。复现命令见 [运行说明](SETUP.md)。
