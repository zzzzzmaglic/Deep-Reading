# Deep Reading · 原生 iOS 客户端

这是当前产品演示使用的 SwiftUI / UIKit 客户端。目录名保留自早期视觉原型阶段；现已接入 Supabase，并包含阅读器、阅读资产、知识库、AI 伴读和 AI 阅读报告。

- 工程：`DeepReadingVisualPrototype.xcodeproj`
- Scheme：`DeepReadingVisualPrototype`
- 最低系统：iOS 26.0
- 数据配置：`DeepReadingVisualPrototype/Configuration/Debug.xcconfig.example`
- 运行与验证：[完整说明](../docs/SETUP.md)
- 架构：[客户端、数据与 AI 服务](../docs/ARCHITECTURE.md)

打开工程后，使用自己的 Supabase 配置和 Signing Team，选择本机可用的 iOS 26 模拟器运行。Debug 使用 Keychain；无签名 Release simulator 使用当前客户端实例的内存会话存储。
