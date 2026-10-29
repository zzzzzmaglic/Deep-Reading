# 技术架构

当前演示采用原生 iOS 客户端与 Supabase 后端。SwiftUI 负责页面组合，UIKit / TextKit 处理需要原生文本能力与精确交互的部分；客户端通过 Repository 访问数据，通过 Edge Functions 使用模型服务。

| 层次 | 主要实现 | 职责 |
| --- | --- | --- |
| 页面与交互 | SwiftUI、UIKit、TextKit | 阅读器、资产卡片、知识库、AI Sheet、报告弹窗 |
| 状态与数据访问 | Coordinator、Repository、Supabase Swift SDK | 页面状态、选区和资产联动、异步数据加载 |
| 身份与存储 | Supabase Auth、PostgreSQL、RLS、RPC | 匿名会话、用户数据隔离、受控写入 |
| AI 服务 | TypeScript Edge Functions、DeepSeek | 服务端上下文组装、模型调用、SSE、报告管线 |

## 阅读资产

纯划线、关联型笔记与独立型笔记共用阅读资产模型。锚点关联文章与正文块，标签关联资产。文章汇总页和标签详情页使用资产卡片交互，“在文中显示”携带锚点进入阅读器定位。

源代码入口：客户端 `ios_visual_prototype/DeepReadingVisualPrototype/Reader/`、`Assets/`、`Knowledge/`、`Data/`；数据库 `supabase/migrations/`。

## AI 伴读

客户端发送文章 ID、问题、可选引用与锚点，以及受长度约束的会话历史。服务端验证匿名身份，读取文章标题及所有有序 `article_blocks`，组装模型上下文。当前上下文来源是数据库正文块，不能与阅读报告使用的 `article_full_texts` 混为一谈。

模型输出以 SSE 的 `started`、`delta`、`completed`、`error` 事件传回客户端。客户端增量显示内容，并支持停止、重试。会话历史保留在当前阅读器内存中。

源代码：[ai-companion](../supabase/functions/ai-companion/)。

## 阅读报告：两次模型调用

1. 读取当前文章的用户阅读资产，排除纯划线和空白笔记；按笔记正文可见字符数选择最长的一条，关联型笔记的引用不计入长度。
2. 从 `article_full_texts` 读取完整文章，以所选笔记为认知分析依据、文章为理解上下文，第一次调用生成结构化分析 JSON；协议校验失败时允许一次相同请求重试。
3. 根据分析与选定组件，组装报告开头、认知展开与认知价值提示词，第二次调用生成报告正文。
4. 客户端显示报告与阅读数据；较长正文可滚动查看。没有有效笔记时返回无法生成状态，不以纯划线替代笔记依据。

两条 AI 路径均固定调用 `deepseek-flash`。报告中的 Edison、专注时长和对话次数来自演示资料配置；阅读资产数量读取实际数据。

源代码：[reading-report](../supabase/functions/reading-report/)。

## 配置与会话

客户端只配置 Supabase URL 与 anon key。DeepSeek API Key 保留在服务端环境，数据访问仍由 RLS/RPC 和函数身份验证约束。

Debug 和真机客户端使用默认 Keychain；无签名 Release simulator 使用客户端实例内的内存会话存储，避免 Keychain entitlement 缺失导致登录成功但后续请求没有 token。该路径不将凭证写入磁盘。

## 代码演进

`app/` 保留早期 Flutter 实现与测试；当前演示对应 `ios_visual_prototype/`。历史设计文档记录当时的方案，实际运行入口与现有架构以根 README、本文件及源码为准。
