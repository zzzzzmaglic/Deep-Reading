# 阅读器视觉层重建 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 iPhone 16（393 × 852 pt、iOS 26.5）上重建 Figma 01–08 的阅读器及阅读资产覆盖态，同时不改变 Task 6–9 已实现的业务行为。

**Architecture:** Flutter 继续渲染正文、渐进遮罩、选择菜单和资产覆盖层；`ReaderGlassControlSurface` 用四个小型 iOS Platform View 承载 Apple 原生玻璃控件，避免整屏原生视图吞掉 Flutter 的滚动和文本选择手势。原生 Swift 层只渲染玻璃与 SF Symbols，并通过 `MethodChannel` 发送四个可用动作；AI 入口仅呈现视觉。Flutter 仍是全部导航和数据写入的唯一所有者。

**Tech Stack:** Flutter 3.47 / Dart 3.13、`flutter_svg` 2.3.0、UIKit `UIGlassEffect`（iOS 26+）、`UIVisualEffectView` 回退、Flutter widget tests、XCTest、iPhone 16 iOS 26.5 Simulator。

## Global Constraints

- 仅实现 Figma 01–08；不得进入阅读流、完成阅读/报告、知识库或 AI Sheet。
- 冻结 Figma 与 `PRD-首轮核心用户路径UX设计.md` 是视觉与交互事实来源；iPhone 16 393 × 852 pt 是截图基准。
- 01–08 阅读器背景为 `#F8F5EF`，正文默认 21 pt / 31 pt、横向 28 pt；顶部遮罩 `0,-8,393,148`、底部遮罩 `0,762,393,98`，两者 blur radius 为 9.1。
- 在 iOS 26+ 使用官方 `UIGlassEffect`；不得将 Liquid Glass、SF Symbols 或 Apple 系统图标导出为图片。iOS 15–25 只能提供功能与布局回退。
- 保留既有 Supabase、数据模型、阅读进度、选择适配器、划线、资产与路由契约；不得修改迁移或种子数据。
- 当前工作树已有本机环境产生的未提交改动；不得重置、覆盖或清理这些文件。
- 用户确认短篇 Demo 保留完整 472 个非空白字符内容（含标题）与一张用户提供图片，接受实际约 1.7 屏高度；不得为 1.5 屏目标删改原文。
- `Aa` 与 AI 均为不可触发视觉；只有返回、汇总、独立型笔记播放一次 180 ms 的 0.92 → 1.06 → 1.0 回弹。
- 本轮不提交、不推送、不创建分支。

---

## File Structure

| 文件 | 职责 |
| --- | --- |
| `app/lib/features/reader/presentation/reader_visual_tokens.dart` | 冻结 Figma 的颜色、尺寸、边距和渐进遮罩组件。 |
| `app/lib/features/reader/presentation/reader_glass_control_surface.dart` | Flutter 的四个原生玻璃控件槽位、显隐同步和动作回调。 |
| `app/lib/features/reader/presentation/reader_screen.dart` | 使用视觉 token 和 control surface；保持正文/业务逻辑不变。 |
| `app/ios/Runner/ReaderGlassControlsPlatformView.swift` | UIKit Platform View、iOS 26 Liquid Glass 和低版本回退。 |
| `app/ios/Runner/AppDelegate.swift` | 注册 `deep-reading/reader-glass-control` Platform View factory。 |
| `app/ios/Runner.xcodeproj/project.pbxproj` | 将新 Swift 文件加入 Runner 和 RunnerTests 编译目标。 |
| `app/lib/features/reading_assets/presentation/*.dart` | 按 05–08 重建卡片、编辑器、删除确认和标签 Sheet 的视觉层。 |
| `app/test/.../reader_visual_tokens_test.dart` | 验证冻结几何参数和遮罩层级。 |
| `app/test/.../reader_glass_control_surface_test.dart` | 验证显隐、禁用 AI 的常驻视觉和四个动作回调。 |
| `app/test/.../reading_asset_card_test.dart`、`tag_management_sheet_test.dart` | 验证覆盖层禁用底层控件以及 05–08 的视觉结构。 |
| `app/ios/RunnerTests/ReaderGlassControlsPlatformViewTests.swift` | 验证 iOS 26 使用 `UIGlassEffect`，低版本回退，并发出 action。 |

### Task 1: 冻结阅读器视觉 token 与遮罩层

**Files:**
- Create: `app/lib/features/reader/presentation/reader_visual_tokens.dart`
- Create: `app/test/features/reader/presentation/reader_visual_tokens_test.dart`
- Modify: `app/lib/features/reader/presentation/reader_screen.dart`
- Modify: `app/test/features/reader/presentation/reader_screen_test.dart`

**Interfaces:**
- Produces: `ReaderVisualTokens`, `ReaderEdgeBlur`, `ReaderEdgeBlurPlacement`。
- Consumes: `ReaderThemeMode`，由 `ReaderScreen` 选择浅/深背景。

- [x] **Step 1: 写出冻结几何的失败测试**

```dart
testWidgets('reader paints Figma edge blur above content and below controls', (tester) async {
  await pumpReaderAtIphone16Size(tester);

  expect(find.byKey(const Key('reader-top-edge-blur')), findsOneWidget);
  expect(find.byKey(const Key('reader-bottom-edge-blur')), findsOneWidget);
  expect(tester.getRect(find.byKey(const Key('reader-bottom-edge-blur'))),
      const Rect.fromLTWH(0, 762, 393, 98));
});
```

- [x] **Step 2: 运行测试，确认失败**

Run: `cd app && flutter test test/features/reader/presentation/reader_visual_tokens_test.dart`

Expected: FAIL，因为 token、遮罩 widget 和 key 都不存在。

- [x] **Step 3: 实现最小视觉基础层**

```dart
abstract final class ReaderVisualTokens {
  static const paper = Color(0xfff8f5ef);
  static const contentHorizontal = 28.0;
  static const bodyFontSize = 21.0;
  static const bodyLineHeight = 31 / 21;
  static const topBlur = Rect.fromLTWH(0, -8, 393, 148);
  static const bottomBlur = Rect.fromLTWH(0, 762, 393, 98);
  static const blurSigma = 9.1;
}
```

将 `ReaderScreen` 的背景、正文边距和文本样式迁移到 token；在正文之后、控件之前插入两个 `ReaderEdgeBlur`，使用 `ImageFilter.blur` 与边缘渐变的 `ShaderMask`。保留滚动和选择 child 的原始树形结构。

- [x] **Step 4: 运行定向测试和现有阅读器测试**

Run: `cd app && flutter test test/features/reader/presentation/reader_visual_tokens_test.dart test/features/reader/presentation/reader_screen_test.dart`

Expected: 全部通过。

- [x] **Step 5: 格式化并审查 diff（不提交）**

Run: `cd app && dart format lib/features/reader/presentation/reader_visual_tokens.dart lib/features/reader/presentation/reader_screen.dart test/features/reader/presentation/reader_visual_tokens_test.dart && git diff --check`

Expected: `git diff --check` 无输出。

### Task 2: 原生 Liquid Glass 控件桥接

**Files:**
- Create: `app/lib/features/reader/presentation/reader_glass_control_surface.dart`
- Create: `app/test/features/reader/presentation/reader_glass_control_surface_test.dart`
- Create: `app/ios/Runner/ReaderGlassControlsPlatformView.swift`
- Create: `app/ios/RunnerTests/ReaderGlassControlsPlatformViewTests.swift`
- Modify: `app/ios/Runner/AppDelegate.swift`
- Modify: `app/ios/Runner.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `ReaderGlassAction { back, summary, style, standaloneNote }` and `ReaderGlassControlSurface`.
- Consumes: `bool controlsVisible` plus four non-null `VoidCallback`s from `ReaderScreen`.
- Channel: `deep-reading/reader-glass-control`; native→Flutter message shape is `{ "action": "back|summary|style|standaloneNote" }`.

- [x] **Step 1: 写 Flutter 端失败测试**

```dart
testWidgets('AI stays visible while the other reader controls hide', (tester) async {
  final actions = <ReaderGlassAction>[];
  await tester.pumpWidget(testSurface(controlsVisible: false, onAction: actions.add));

  expect(find.byKey(const Key('reader-glass-ai')), findsOneWidget);
  expect(find.byKey(const Key('reader-glass-back')), findsNothing);
});
```

- [x] **Step 2: 写 iOS 端失败测试并运行两类测试**

```swift
func testUsesLiquidGlassOnIOS26() throws {
  let view = ReaderGlassControlView(kind: .back, materialProvider: .iOS26)
  XCTAssertTrue(view.effectView.effect is UIGlassEffect)
}
```

Run: `cd app && flutter test test/features/reader/presentation/reader_glass_control_surface_test.dart && xcodebuild test -project ios/Runner.xcodeproj -scheme Runner -destination 'platform=iOS Simulator,name=Deep Reading · iPhone 16,OS=26.5' -only-testing:RunnerTests/ReaderGlassControlsPlatformViewTests`

Expected: Flutter test FAIL（surface 不存在）；XCTest FAIL（class 不存在）。

- [x] **Step 3: 实现四个小型 Platform View 与回退**

```swift
if #available(iOS 26.0, *) {
  effectView.effect = UIGlassEffect(style: .regular)
} else {
  effectView.effect = UIBlurEffect(style: .systemChromeMaterialLight)
}
```

创建 `ReaderGlassControlFactory: NSObject, FlutterPlatformViewFactory`，只接受 `back`、`summary`、`tools` 和 `aiBackground` 四个 kind。每个 view 的 UIKit frame 与 Flutter `SizedBox` 完全相同；`back`、`summary`、`tools` 发送 MethodChannel action，`aiBackground` 禁用原生 user interaction，让 Flutter 上层 SVG 和点击语义接收事件。按钮分别采用 SF Symbol：`chevron.left`、`ellipsis`、`textformat.size`、`square.and.pencil`。

`ReaderGlassControlSurface` 在 iOS 使用四个 `UiKitView`，在 widget test / 非 iOS 使用同尺寸的 `ReaderGlassFallbackButton`。对外只暴露 `controlsVisible` 与四个 callback；AI 入口使用禁用语义和命中测试。其 `Stack` 固定为左上 20/52、右上 329/52、左下 22/780、右下 329/780。

- [x] **Step 4: 注册与编译 Swift 文件**

```swift
override func application(...) -> Bool {
  ReaderGlassControlFactory.register(with: self)
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

将 `ReaderGlassControlsPlatformView.swift` 加入 Runner Sources，并将 `ReaderGlassControlsPlatformViewTests.swift` 加入 RunnerTests Sources；不得改变 deployment target 15.0。

- [x] **Step 5: 运行桥接验证**

Run: `cd app && flutter test test/features/reader/presentation/reader_glass_control_surface_test.dart && xcodebuild test -project ios/Runner.xcodeproj -scheme Runner -destination 'platform=iOS Simulator,name=Deep Reading · iPhone 16,OS=26.5' -only-testing:RunnerTests/ReaderGlassControlsPlatformViewTests`

Expected: 两类测试均通过。

- [x] **Step 6: 格式化与 Xcode 工程检查（不提交）**

Run: `cd app && dart format lib/features/reader/presentation/reader_glass_control_surface.dart test/features/reader/presentation/reader_glass_control_surface_test.dart && git diff --check && xcodebuild -project ios/Runner.xcodeproj -scheme Runner -showBuildSettings >/dev/null`

Expected: 三条命令均以 0 退出。

### Task 3: 将控件表面接入阅读器行为

**Files:**
- Modify: `app/lib/features/reader/presentation/reader_screen.dart`
- Modify: `app/test/features/reader/presentation/reader_screen_test.dart`

**Interfaces:**
- Consumes: `ReaderGlassControlSurface` 和 `ReaderVisualTokens`。
- Produces: 当前 01/02/03/03a/04/04a/04b/04c 下正确的控件显隐与动作分发。

- [x] **Step 1: 写回归失败测试**

```dart
testWidgets('reader body hides only conditional glass controls', (tester) async {
  await _pumpReader(tester);
  await tester.tap(find.text('Article block 1'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('reader-glass-back')), findsNothing);
  expect(find.byKey(const Key('reader-glass-tools')), findsNothing);
  expect(find.byKey(const Key('reader-glass-ai')), findsOneWidget);
});
```

- [x] **Step 2: 运行失败测试**

Run: `cd app && flutter test test/features/reader/presentation/reader_screen_test.dart --plain-name 'reader body hides only conditional glass controls'`

Expected: FAIL，因为现有 `_buildToolbar` 使用四个 Material `IconButton`，且会一并隐藏 AI。

- [x] **Step 3: 以 control surface 替换 `_buildToolbar`**

```dart
ReaderGlassControlSurface(
  controlsVisible: _controlsVisible,
  onBack: () => Navigator.of(context).maybePop(),
  onSummary: () => context.push('/reader/${Uri.encodeComponent(widget.articleId)}/summary'),
  onStyle: () => _showStyleSheet(context),
  onStandaloneNote: _requestStandaloneNote,
)
```

AI 的视觉入口必须始终存在，但以禁用语义和命中测试渲染，不创建 AI Sheet、不显示占位提示、也不新增 AI 业务代码。选择会话活跃、资产卡片或 Sheet 打开时，保存并恢复打开前的 `_controlsVisible` 值，覆盖层期间禁用 surface 的 pointer。

- [x] **Step 4: 运行全部阅读器 widget 测试**

Run: `cd app && flutter test test/features/reader/presentation`

Expected: 目录中的全部 reader presentation 测试通过。

- [x] **Step 5: 验证静态分析（不提交）**

Run: `cd app && flutter analyze && git diff --check`

Expected: `flutter analyze` 和 `git diff --check` 均无 error。

### Task 4: 重建 05–08 阅读资产卡片与标签 Sheet 视觉层

**Files:**
- Modify: `app/lib/features/reading_assets/presentation/reading_asset_card.dart`
- Modify: `app/lib/features/reading_assets/presentation/reading_asset_editor.dart`
- Modify: `app/lib/features/reading_assets/presentation/delete_asset_dialog.dart`
- Modify: `app/lib/features/reading_assets/presentation/tag_management_sheet.dart`
- Modify: `app/test/features/reading_assets/presentation/reading_asset_card_test.dart`
- Modify: `app/test/features/reading_assets/presentation/reading_asset_card_review_test.dart`
- Create: `app/test/features/reading_assets/presentation/tag_management_sheet_test.dart`

**Interfaces:**
- Consumes: 现有 `ReadingAssetRepository`、`AssetEditorController`、`TagManagementSheet.onConfirm` 和 delete dialog 的返回值。
- Produces: 与 Figma 05–08 一致的 345 pt 宽、460 pt 高、28 pt 顶角覆盖态；接口签名与数据调用保持不变。

- [ ] **Step 1: 写覆盖层与标签 Sheet 的失败测试**

```dart
testWidgets('tag sheet is half-height and locks the system tag', (tester) async {
  await tester.pumpWidget(testTagSheet());
  expect(tester.getSize(find.byKey(const Key('tag-management-sheet'))).height, 426);
  expect(tester.widget<CheckboxListTile>(find.byKey(const Key('tag-system'))).onChanged, isNull);
});

testWidgets('asset overlay absorbs taps outside its card', (tester) async {
  await pumpAssetCard(tester);
  await tester.tapAt(const Offset(8, 400));
  expect(find.byType(ReadingAssetCard), findsNothing);
  expect(bottomReaderCallbackCalls, 0);
});
```

- [ ] **Step 2: 运行失败测试**

Run: `cd app && flutter test test/features/reading_assets/presentation/reading_asset_card_test.dart test/features/reading_assets/presentation/tag_management_sheet_test.dart`

Expected: FAIL，因为现有 Card、默认 dialog 和 0.5 倍屏高 Sheet 没有 Figma key、尺寸和完整的拦截行为。

- [ ] **Step 3: 实现 Figma 05–08 的视觉结构**

将 `showDialog` 替换为透明 barrier 的全屏 `ReadingAssetOverlay`：卡片在 iPhone 16 上位于 x=24、y=196，尺寸 345 × 460 pt、顶角 28 pt、暖白/白色不透明底，外围展示与 Reader 一致的渐进虚化背景。查看态使用 `#标签`、红色删除图标和右下 44 pt 蓝色圆形编辑/完成按钮；编辑态打开键盘时通过 `AnimatedPadding(viewInsets)` 上移，内部滚动但完成按钮固定。

`TagManagementSheet` 以 `Key('tag-management-sheet')` 标识，初始高度严格为 426 pt；顶部右侧文案改为“确定”，锁定标签显示锁 icon 且 `onChanged == null`，新建标签行留在列表最后并原地变为输入框。删除确认使用 Figma 的居中圆角确认卡而不是默认 Material `AlertDialog`。所有保存、放弃、删除和标签 repository 调用保持原实现。

- [ ] **Step 4: 运行阅读资产测试**

Run: `cd app && flutter test test/features/reading_assets/presentation test/features/reader/presentation/reader_screen_test.dart`

Expected: reading-assets presentation 与 reader screen 测试全部通过。

- [ ] **Step 5: 格式化、分析和 diff 检查（不提交）**

Run: `cd app && dart format lib/features/reading_assets/presentation test/features/reading_assets/presentation && flutter analyze && git diff --check`

Expected: 所有命令以 0 退出，且不产生提交。

### Task 5: iPhone 16 iOS 26.5 构建与视觉证据

**Files:**
- Modify: `HADNOFF_MAC.md`
- No source changes required unless verification exposes a measured mismatch.

**Interfaces:**
- Consumes: Tasks 1–4 的 Debug build、Mac 本地 Supabase 和 iPhone 16 Simulator。
- Produces: 01、02、03a、04b、05、06、07、08 的命名截图及交接中的验证事实。

- [ ] **Step 1: 运行完整 Flutter 回归**

Run: `cd app && flutter test && flutter analyze`

Expected: 所有测试通过，分析无 error。

- [ ] **Step 2: 构建并启动 iPhone 16 Debug App**

Run: `cd app && flutter run -d 26B9A0D8-2E67-40FF-886A-DAFA0E02E513 --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY='<local publishable key>'`

Expected: 编译成功，应用在 iPhone 16 iOS 26.5 启动，且只连接 Mac 本地 Supabase。命令输出中不得复制或记录 service-role、Storage secret、DeepSeek key。

- [ ] **Step 3: 捕获视觉状态**

Run: `xcrun simctl io 26B9A0D8-2E67-40FF-886A-DAFA0E02E513 screenshot /private/tmp/deep-reading-reader-01.png`

Expected: 得到 393 × 852 pt 基准截图。以同样命名规则捕获 02、03a、04b、05、06、07、08；仅在此处按 Figma 路径操作以验证视觉状态，不执行超出 01–08 的手工验收。

- [ ] **Step 4: 叠图核验与记录**

将每张 Simulator 截图与对应 Figma Frame 以 50% 透明度叠放，逐项核对：正文边距/字级、按钮 x/y/44 pt、工具组 119 × 44 pt、遮罩位置、卡片 371 pt、Sheet 426 pt、图标和层级。把实际通过项、测得偏差和截图绝对路径追加到 `HADNOFF_MAC.md`；若存在偏差，只进入对应 Task 的修复循环，不修改业务范围。

- [ ] **Step 5: 最终工作树审计（不提交）**

Run: `git status --short && git diff --check`

Expected: 列出所有有意改动；`git diff --check` 无输出；无 commit、push 或 branch 操作。

## Plan Self-Review

- 覆盖：Task 1 实现 01/02 的正文和遮罩；Task 2–3 实现控件原生材质与 03–04 的状态；Task 4 实现 05–08；Task 5 产生 iPhone 16 视觉证据与交接记录。
- 无占位扫描：本计划没有空白步骤或未定义的后续工作；所有新接口、channel、文件、命令和验收尺寸已定义。
- 一致性：`ReaderGlassControlSurface` 始终以四个 callback 对外暴露；AI 入口无 action，原生 action string 与 `ReaderGlassAction` 枚举一一对应；Platform View type 在 Swift 与 Flutter 中均为 `deep-reading/reader-glass-control`。
