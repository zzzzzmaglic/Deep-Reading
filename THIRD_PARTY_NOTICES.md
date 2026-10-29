# 第三方代码与演示素材

本文件记录来源，不替代各第三方原有许可证，也不将第三方内容重新许可为本项目自身代码的许可。

## UnionTabView

- 作者：Ben Sage / Union St。
- 上游：[unionst/union-tab-view](https://github.com/unionst/union-tab-view)。
- 本地目录：`ios_visual_prototype/DeepReadingVisualPrototype/Vendor/UnionTabView/`。
- `GlassTabBar.swift`、`BlurFadeModifier.swift` 的来源记录为 tag `1.2.0`，commit `abf9afc364b315d1d058975c6ebbfabde6be06ea`。
- A/B 诊断使用的 `UnionTabView.swift` 来源为 commit `7f901757c7b6e4cca62cf637f8e005ea366b4c7d`。本地代码存在适配修改，不代表上游原样实现。
- 保留的 `UPSTREAM_README.md` 声明 MIT，`ORIGIN.md` 记录来源；该版本未附独立 LICENSE 正文，尚未补造版权年份或上游许可证文本。

## 包管理依赖

原生客户端的直接依赖为 `supabase-swift`，具体版本及传递依赖由 `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` 锁定。早期 Flutter 实现的依赖记录在 `app/pubspec.yaml` 和 `app/pubspec.lock`。各依赖遵循各自仓库中的许可。

## 开发辅助文件

`.codex/skills/` 是随历史开发保留的第三方辅助资料，不是应用运行时依赖。各目录中的来源声明及现有许可文件继续保留；根目录 MIT 许可不覆盖这些第三方材料。它们不应作为本项目原创产品代码展示。

## 文章、配图及设计资源

四篇文章的正文与节选保存在 `supabase/seed.sql` 中，配图主要位于 `ios_visual_prototype/DeepReadingVisualPrototype/Assets.xcassets/`；历史 Flutter 配图位于 `app/assets/images/`。PRD 图像位于 `docs/assets/prd/`。

文章标题：

- 1600–2100 年的公司简史
- 为你的大脑收集训练数据
- 达尔文是个“懒虫”，你也应该如此
- 当我们在聊情商时，到底在聊什么？

维护者于 2026-10-28 确认上述演示文章与配图可公开使用。保留资料中的原作者、策展与版权标注；该确认不表示这些内容适用本项目代码的 MIT 许可，也不额外授予第三方任意再许可的权利。
