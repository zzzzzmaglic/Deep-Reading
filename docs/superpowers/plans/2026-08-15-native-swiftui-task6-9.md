# Native SwiftUI Task 6–9 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static `ios_visual_prototype` runtime with an online-first SwiftUI implementation of Task 6–9, using the existing local Supabase contract and preserving the approved reader visual system.

**Architecture:** SwiftUI owns navigation, screen state, Liquid Glass controls, sheets, asset cards, and summary routing. A single UIKit `UITextView` TextKit bridge renders the ordered article blocks, supports native selection and highlights, and translates `NSRange` selections to the Supabase UTF-16 anchor contract. Data access is isolated behind Swift `async` repository protocols and a single `supabase-swift` client.

**Tech Stack:** Swift 6, SwiftUI, UIKit/TextKit, XCTest/XCUITest, Swift Package Manager, `supabase-swift`, iPhone 16 iOS 26 Simulator, local Docker Supabase.

## Global Constraints

- Modify only `ios_visual_prototype/`, its test targets, `HADNOFF_MAC.md`, and this plan; do not modify Flutter `app/`, Supabase migrations/seed/RLS/RPC, PRD, `AGENTS.md`, `PROJECT_STATE.md`, or `HANDOFF.md`.
- Keep `feature/first-core-user-path`; make local commits only and never push, create, or switch branches.
- Read `SUPABASE_URL` and `SUPABASE_ANON_KEY` from an untracked Debug `.xcconfig` or Scheme environment. Never write keys to the repository, log files, screenshots, or handoff.
- Use anonymous Supabase Auth and only existing RPCs: `create_highlight_asset`, `create_standalone_note`, `update_reading_asset`, `set_asset_tags`, `delete_reading_asset`, `upsert_reading_progress`, `create_tag`, `save_reading_asset`, and `create_standalone_note_with_tags`.
- Anchor offsets are UTF-16 values. Use `String.UTF16View` / `NSRange`, never `String.count`.
- Keep the 393 × 852 iPhone 16 reader geometry: top controls at their approved Figma positions, 148 pt top overlay, 98 pt bottom edge region, and existing background/image asset. Preserve Liquid Glass controls and 350 ms chrome/progress behavior.
- The private `CAFilter` progressive blur remains conditional to Debug + Simulator. Release code must compile without it and use public iOS 26 scroll-edge treatment.
- Do not implement Task 10+, AI, completion/report, reading feed, Appetize, real-account authentication, offline edits, sync queues, or conflict resolution.

---

## Planned File Structure

| Path | Responsibility |
| --- | --- |
| `ios_visual_prototype/DeepReadingVisualPrototype/Configuration/SupabaseRuntimeConfiguration.swift` | Validate public runtime URL/key and create the error shown for missing configuration. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Configuration/Debug.xcconfig.example` | Field-name-only configuration template, kept safe to commit. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseClientFactory.swift` | One authenticated `SupabaseClient` instance. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseArticleRepository.swift` | Fetch `articles`, ordered `article_blocks`, and reading progress. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseReadingAssetRepository.swift` | Tables-to-domain reads and the exact existing RPC payloads. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Domain/*.swift` | Immutable `Sendable` article, anchor, asset, tag, draft, route, and progress types plus repository protocols. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderTextLayout.swift` | Build article attributed text/attachment ranges and map selection/progress to UTF-16 anchors. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderTextView.swift` | `UITextView` representable, native selection menu, persistent highlight drawing, and scroll callbacks. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderCoordinator.swift` | Main-actor loading, chrome state, 350 ms progress throttle, asset refresh, and anchor positioning. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift` | Production reader composition; moves static visual components behind real state. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Assets/*.swift` | Card, editor draft, tag sheet, discard/delete confirmation, and standalone-note entry. |
| `ios_visual_prototype/DeepReadingVisualPrototype/Summary/ArticleAssetSummaryScreen.swift` | Current-article asset list, card presentation, selection/delete, and anchor-return routing. |
| `ios_visual_prototype/DeepReadingVisualPrototypeTests/*.swift` | Pure models, selection conversion, repository payload, throttling, draft, and routing XCTest coverage. |
| `ios_visual_prototype/DeepReadingVisualPrototypeUITests/*.swift` | Local Supabase reader → asset → summary → anchor path. |
| `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj` | Target source membership, test target, Debug config, and `supabase-swift` package resolution. |
| `HADNOFF_MAC.md` | Native migration completion, local verification command, and remaining exclusions. |

### Task 1: 迁移阶段 A — 原 Task 6 的原生运行时与领域契约前置

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Configuration/SupabaseRuntimeConfiguration.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Configuration/Debug.xcconfig.example`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseClientFactory.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Domain/Article.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Domain/ReadingAsset.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Domain/RepositoryProtocols.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/SupabaseRuntimeConfigurationTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj/project.pbxproj`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift`

**Interfaces:**
- Produces `SupabaseRuntimeConfiguration(url: URL, anonKey: String)` and `static func load(bundle: Bundle = .main) throws -> SupabaseRuntimeConfiguration`.
- Produces `ArticleRepository`, `ReadingAssetRepository`, `SessionAuthenticating`, `ReaderRoute(articleID: UUID, anchorID: UUID?, origin: ReaderOrigin)`.
- Produces immutable domain types: `Article`, `ArticleBlock`, `ArticleBlockKind`, `TextAnchor`, `ReadingAsset`, `ReadingAssetKind`, `Tag`, `ReaderPosition`, and `AssetDraft`.

- [ ] **Step 1: Write failing configuration and domain tests**

```swift
func testLoadRejectsMissingPublicConfiguration() {
    XCTAssertThrowsError(try SupabaseRuntimeConfiguration.load(values: [:])) { error in
        XCTAssertEqual(error as? SupabaseRuntimeConfigurationError, .missingValue("SUPABASE_URL"))
    }
}

func testReadingAssetDerivesLinkedNoteOnlyWhenItHasAnchorAndNote() {
    XCTAssertEqual(ReadingAsset(anchor: anchor, noteContent: nil).kind, .highlight)
    XCTAssertEqual(ReadingAsset(anchor: anchor, noteContent: "想法").kind, .linkedNote)
    XCTAssertEqual(ReadingAsset(anchor: nil, noteContent: "想法").kind, .standaloneNote)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DeepReadingVisualPrototypeTests/SupabaseRuntimeConfigurationTests
```

Expected: FAIL because the native configuration and domain contracts do not exist.

- [ ] **Step 3: Add packages, safe configuration, domain models, and startup error UI**

Add `https://github.com/supabase/supabase-swift.git` through Xcode SPM and link its `Supabase` product only to the App target. Add a Debug configuration-file reference using `SUPABASE_URL = $(SUPABASE_URL)` and `SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY)`; commit only the example file:

```xcconfig
// Copy to Debug.xcconfig and set values locally. Do not commit the copy.
SUPABASE_URL =
SUPABASE_ANON_KEY =
```

Define each table/API model with snake-case keys, `UUID` IDs, and `Sendable`. Change the scene root from `ReaderPrototypeView()` to an `AppRootView` that displays a configuration error with a Retry button when `load` fails; it must never fall back to `PrototypeArticle.demo`. Leave static fixture data available only to previews/tests.

- [ ] **Step 4: Run focused and full existing tests**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS. Launch once without a local configuration and verify the user-readable missing-configuration view contains no article text or secret value.

- [ ] **Step 5: Commit the runtime foundation**

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype ios_visual_prototype/DeepReadingVisualPrototypeTests ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj
git commit -m "feat: establish native Supabase runtime contracts"
```

### Task 2: 迁移阶段 B — 原 Task 6 的匿名会话与 Supabase 数据访问

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseArticleRepository.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Data/SupabaseReadingAssetRepository.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Data/AppSessionStore.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/Fakes/FakeRepositories.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/SupabaseReadingAssetRepositoryTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift`

**Interfaces:**
- `AppSessionStore.bootstrap() async throws` returns only after an existing or new anonymous session exists.
- `ArticleRepository.readArticle(id:) async throws -> Article`, `readProgress(articleID:) async throws -> ReaderPosition?`.
- Mutations accept domain values and issue the exact `p_*` RPC dictionaries listed in the global constraints.

- [ ] **Step 1: Write failing repository payload tests**

```swift
func testCreateHighlightUsesUTF16AnchorPayload() async throws {
    try await repository.createHighlight(articleID: articleID, anchor: anchor, checksum: "sha256")
    XCTAssertEqual(remote.lastRPC?.name, "create_highlight_asset")
    XCTAssertEqual(remote.lastRPC?.parameters["p_start_utf16_offset"] as? Int, 6)
    XCTAssertEqual(remote.lastRPC?.parameters["p_end_utf16_offset"] as? Int, 14)
}

func testAssetsJoinAnchorAndTagsBeforeFilteringCurrentArticle() async throws {
    let assets = try await repository.readAssets(articleID: articleID)
    XCTAssertEqual(assets.map(\\.id), [anchoredAssetID, standaloneArticleAssetID])
    XCTAssertEqual(assets.first?.tags.map(\\.name), ["摘录与思考", "商业化"])
}
```

- [ ] **Step 2: Run the repository tests to verify they fail**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DeepReadingVisualPrototypeTests/SupabaseReadingAssetRepositoryTests
```

Expected: FAIL because no Swift data source/repository exists.

- [ ] **Step 3: Implement anonymous session bootstrap and repositories**

`AppSessionStore` must check `client.auth.currentSession` before `signInAnonymously()`. The article query selects the requested `articles` row and `article_blocks`, ordering blocks by `position.asc`. Asset reads select `reading_assets`, `asset_anchors`, `tags`, and `asset_tags`, join them in memory by UUID, then filter by anchored article ID or standalone article ID.

For every mutation call `client.rpc(name, params: payload)` using this shape:

```swift
[
  "p_article_id": articleID.uuidString,
  "p_start_block_id": anchor.startBlockID.uuidString,
  "p_end_block_id": anchor.endBlockID.uuidString,
  "p_start_utf16_offset": anchor.startUTF16Offset,
  "p_end_utf16_offset": anchor.endUTF16Offset,
  "p_selected_text": anchor.selectedText,
  "p_content_checksum": checksum,
]
```

Decode returned UUIDs and refresh the returned asset from the read model. Surface transport/auth/RPC errors to the caller; do not add an offline queue or a static data fallback.

- [ ] **Step 4: Verify unit and local-service behavior**

Run:

```bash
supabase status
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS. In the simulator with local Debug values, verify anonymous bootstrap completes and the seed article ID/blocks are obtained from Supabase rather than `ReaderPrototypeModel`.

- [ ] **Step 5: Commit repositories**

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/Data ios_visual_prototype/DeepReadingVisualPrototypeTests ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift
git commit -m "feat: add native article and asset repositories"
```

### Task 3: 迁移阶段 C — 原 Task 6：TextKit 在线阅读器、进度与锚点

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderTextLayout.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderTextView.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderCoordinator.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/ReaderTextLayoutTests.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/ReaderCoordinatorTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/ReaderPrototypeView.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/ReaderGlassControls.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/ReaderOverlayViews.swift`

**Interfaces:**
- `ReaderTextLayout(article:image:)` exposes `range(forBlockID:)`, `anchor(for: NSRange) throws`, `position(forVisibleUTF16Location:)`, and `range(for: TextAnchor)`.
- `ReaderCoordinator` exposes `load(route:)`, `handleScroll(direction:)`, `handleBodyTap()`, `queueProgress(visibleUTF16Location:)`, `showChrome()`, `hideChrome()`, and `refreshAssets()`.
- `ReaderScreen(route: ReaderRoute, dependencies: ReaderDependencies)` is the only production reader entry.

- [ ] **Step 1: Write failing text-layout and coordinator tests**

```swift
func testSelectionAcrossParagraphsMapsToLocalUTF16Endpoints() throws {
    let anchor = try layout.anchor(for: NSRange(location: firstStart + 2, length: firstRemaining + 4))
    XCTAssertEqual(anchor.startBlockID, firstBlockID)
    XCTAssertEqual(anchor.startUTF16Offset, 2)
    XCTAssertEqual(anchor.endBlockID, secondBlockID)
    XCTAssertEqual(anchor.endUTF16Offset, 4)
}

func testProgressWritesOnceAfter350Milliseconds() async throws {
    coordinator.queueProgress(visibleUTF16Location: 19)
    coordinator.queueProgress(visibleUTF16Location: 31)
    try await clock.advance(by: .milliseconds(350))
    XCTAssertEqual(repository.progressWrites, [ReaderPosition(blockID: secondBlockID, utf16Offset: 4)])
}
```

- [ ] **Step 2: Run reader tests to verify they fail**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DeepReadingVisualPrototypeTests/ReaderTextLayoutTests -only-testing:DeepReadingVisualPrototypeTests/ReaderCoordinatorTests
```

Expected: FAIL because the production reader/text layout is absent.

- [ ] **Step 3: Implement article layout, scroll restoration, visual composition, and progress**

Build one attributed string in article-block order. Paragraph separators must be represented in the layout range map; the `FourForces` image becomes a text attachment whose surrounding ranges preserve subsequent block offsets. Apply asset anchors as attributed background ranges, splitting only at paragraph boundaries. `UITextView` must disable its vertical indicator, expose native text selection, report visible character locations, and scroll to a requested range after layout.

Load the article, then persisted progress. If `route.anchorID` is present, resolve that asset anchor and scroll to it before progress; otherwise restore progress. On down-scroll hide status/chrome after 350 ms; up-scroll or tap on unselected body reveals them. Preserve the existing top 148 pt progressive blur, 98 pt bottom soft edge, controls geometry, control bounce, and `Aa`/AI visual-only behavior. Route the summary button to Task 6's screen. Every progress update sends the visible block/UTF-16 offset after 350 ms and shows a retryable non-blocking error if it fails.

- [ ] **Step 4: Run tests and perform focused iPhone 16 visual verification**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild build -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS. On iPhone 16, verify real article scrolling, no scroll indicator, down/up chrome transition, status-bar transition, tap-to-reveal, seed-image placement, and anchor restoration.

- [ ] **Step 5: Commit Task 6 reader**

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/Reader ios_visual_prototype/DeepReadingVisualPrototype/ReaderPrototypeView.swift ios_visual_prototype/DeepReadingVisualPrototype/ReaderGlassControls.swift ios_visual_prototype/DeepReadingVisualPrototype/ReaderOverlayViews.swift ios_visual_prototype/DeepReadingVisualPrototypeTests
git commit -m "feat: implement native reader progress and anchors"
```

### Task 4: 迁移阶段 D — 原 Task 7：选择、持久划线与独立笔记

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderSelectionAction.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderSelectionMenu.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/ReaderSelectionActionTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderTextView.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderCoordinator.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift`

**Interfaces:**
- `ReaderSelectionAction` has `.highlight`, `.openAssetCard`, `.copy`, and `.explainWithAI` (the latter renders no AI workflow).
- `ReaderCoordinator.performSelection(_:action:) async` converts the selected `NSRange`, invokes the repository, and refreshes attributed highlights.
- `ReaderCoordinator.beginStandaloneNote()` presents a draft with no anchor.

- [ ] **Step 1: Write failing selection behavior tests**

```swift
func testHighlightCreatesOneAssetUsingSelectedTextFromUTF16Range() async throws {
    try await coordinator.performSelection(NSRange(location: 3, length: 5), action: .highlight)
    XCTAssertEqual(repository.createdHighlights.first?.anchor.selectedText, "世界，和物")
    XCTAssertEqual(coordinator.assets.count, 1)
}

func testStandaloneNoteHasNoAnchorAndKeepsCurrentArticleScope() {
    let draft = coordinator.beginStandaloneNote()
    XCTAssertNil(draft.anchor)
    XCTAssertEqual(draft.articleID, articleID)
}
```

- [ ] **Step 2: Run selection tests to verify they fail**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DeepReadingVisualPrototypeTests/ReaderSelectionActionTests
```

Expected: FAIL because the TextKit menu actions are not wired.

- [ ] **Step 3: Implement native text selection and asset creation**

In the `UITextView` coordinator, expose only Copy, 划线, 打开资产卡片, and AI 释义. Copy invokes `UIPasteboard` then restores the preselection chrome state. 划线 maps `selectedRange` through `ReaderTextLayout`, computes the checksum from selected text, calls `create_highlight_asset`, refreshes assets, clears selection, and restores the preselection chrome state. 打开资产卡片 creates a local anchored `AssetDraft` and presents the card; it does not create an asset until the editor save path runs. AI 释义 remains visually unavailable/no-op because Task 11 is excluded.

The reader's bottom note control creates an unanchored draft whose article ID is the current article. Do not emulate selection in SwiftUI `Text`; all anchors come from the TextKit `NSRange` bridge.

- [ ] **Step 4: Run tests and use the Simulator selector**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS. In iPhone 16 Simulator, long-press across two paragraphs, create a highlight, restart the app, and confirm the highlight reloads from local Supabase.

- [ ] **Step 5: Commit Task 7 selection path**

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/Reader ios_visual_prototype/DeepReadingVisualPrototypeTests
git commit -m "feat: add native reader highlights and note entry"
```

### Task 5: 迁移阶段 E — 原 Task 8：资产卡片、草稿、标签与删除

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Assets/ReadingAssetCard.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Assets/AssetEditorView.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Assets/TagManagementSheet.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Assets/DeleteAssetConfirmation.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Assets/AssetDraftController.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/AssetDraftControllerTests.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/TagManagementTests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderCoordinator.swift`

**Interfaces:**
- `AssetDraftController` exposes `hasUnsavedChanges`, `toggle(tag:)`, `addNewTag(name:)`, `save() async throws`, `discard()`, and `delete() async throws`.
- View-mode tag confirmation uses `setAssetTags`; edit-mode completion uses `saveReadingAsset`; standalone save uses `createStandaloneNoteWithTags`.
- `ReadingAssetCard` accepts a close closure carrying the original `ReaderChromeState`.

- [ ] **Step 1: Write failing draft and locked-tag tests**

```swift
func testAddingNoteConvertsHighlightWithoutChangingAssetIdentity() {
    let draft = AssetDraft(asset: highlight, noteContent: nil, selectedTagIDs: [lockedTagID])
    XCTAssertEqual(draft.with(noteContent: "我的想法").kind, .linkedNote)
    XCTAssertEqual(draft.with(noteContent: "我的想法").assetID, highlight.id)
}

func testLockedTagCannotBeDeselected() {
    controller.toggle(tag: lockedTag)
    XCTAssertTrue(controller.draft.selectedTagIDs.contains(lockedTag.id))
}
```

- [ ] **Step 2: Run card/draft tests to verify they fail**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DeepReadingVisualPrototypeTests/AssetDraftControllerTests -only-testing:DeepReadingVisualPrototypeTests/TagManagementTests
```

Expected: FAIL because the draft/card module does not exist.

- [ ] **Step 3: Implement all three asset forms and their mutation timing**

Render the same card shell for pure highlight, linked note, and standalone note. Anchored assets show the fixed-height quote preview; unanchored assets start in the note editor. A pure highlight's visible “添加笔记内容” transitions to editing while retaining the same asset ID. Keep tag changes in `AssetDraft` while editing; on “完成编辑”, call `save_reading_asset(p_asset_id, p_note_content, p_tag_ids)`. In view mode, tag confirmation immediately calls `set_asset_tags`.

The locked `摘录与思考` tag is visibly locked and always selected. New-tag confirmation calls `create_tag`, appends it, and selects it. Tapping outside/down-drag closes an unchanged card; a changed draft presents 继续编辑 / 放弃编辑. Delete confirmation calls `delete_reading_asset`, closes the card only on success, refreshes coordinator assets, and removes the corresponding highlight. Restore exactly the reader chrome state captured before opening any card/sheet.

- [ ] **Step 4: Run unit tests and Simulator interaction checks**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS. On Simulator verify pure highlight → note conversion, independent note creation, locked-tag protection, view/edit save timing, discard confirmation, and permanent deletion.

- [ ] **Step 5: Commit Task 8 assets**

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/Assets ios_visual_prototype/DeepReadingVisualPrototype/Reader ios_visual_prototype/DeepReadingVisualPrototypeTests
git commit -m "feat: implement native reading asset cards and tags"
```

### Task 6: 迁移阶段 F — 原 Task 9：当前文章汇总、锚点返回、UI 测试与交接

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Summary/ArticleAssetSummaryScreen.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/Summary/ArticleAssetSummaryCoordinator.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeTests/ArticleAssetSummaryCoordinatorTests.swift`
- Create: `ios_visual_prototype/DeepReadingVisualPrototypeUITests/Task6To9FlowUITests.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift`
- Modify: `HADNOFF_MAC.md`

**Interfaces:**
- `ArticleAssetSummaryScreen(articleID:origin:)` shows article assets in source order followed by standalone notes sorted by `createdAt` descending.
- `ArticleAssetSummaryCoordinator.showInArticle(_:) -> ReaderRoute` returns `ReaderRoute(articleID: anchor.articleID, anchorID: anchor.id, origin: origin)` and removes the summary from the navigation path.
- `deleteSelectedAssets(_:) async` refreshes only after every delete RPC succeeds.

- [ ] **Step 1: Write failing summary route and deletion tests**

```swift
func testShowInArticleReplacesSummaryWithAnchoredReaderRoute() {
    let route = coordinator.showInArticle(anchoredAsset)
    XCTAssertEqual(route.articleID, articleID)
    XCTAssertEqual(route.anchorID, anchoredAsset.anchor?.id)
    XCTAssertFalse(coordinator.navigationPath.contains(.summary(articleID)))
}

func testDeleteSelectedRefreshesOnlyAfterAllDeletesSucceed() async throws {
    try await coordinator.deleteSelectedAssets([asset1.id, asset2.id])
    XCTAssertEqual(repository.deletedAssetIDs, [asset1.id, asset2.id])
    XCTAssertEqual(coordinator.assets, [])
}
```

- [ ] **Step 2: Run summary tests to verify they fail**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DeepReadingVisualPrototypeTests/ArticleAssetSummaryCoordinatorTests
```

Expected: FAIL because the summary module/routing contract is absent.

- [ ] **Step 3: Implement summary and replacement navigation**

Use one `NavigationStack` path owned by `AppRootView`. The reader's top-right control pushes summary; the summary back action restores the current reader position/chrome state. Sort anchored assets by their article block order and anchor start offset, then append standalone notes in reverse chronological order. Tapping an asset opens the Task 8 card above the same list. Allow selection/delete confirmation; on a successful all-item deletion refresh the list and reader assets.

For “在文中显示”, replace the summary element with `ReaderRoute(anchorID:)`, do not append another reader. After that reader's back action, return to its pre-summary origin rather than re-entering summary. Add accessibility identifiers: `reader-open-summary`, `summary-show-in-article-<assetUUID>`, `reader-text-view`, `asset-save`, and `asset-delete-confirm`.

- [ ] **Step 4: Add and run local-Supabase UI validation**

Configure the UI test only from process environment variables; skip it with an explicit XCTSkip when `SUPABASE_URL`/`SUPABASE_ANON_KEY` are missing. Its flow must: launch, await seed article, create an independent note or test highlight, save, open summary, tap `在文中显示`, then assert `reader-text-view` exists and the summary identifier does not.

Run:

```bash
supabase status
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild build -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -destination 'platform=iOS Simulator,name=iPhone 16'
git diff --check
git status --short
```

Expected: all XCTest pass; UI integration passes when local public variables are provided or explicitly skips otherwise; build succeeds; `git diff --check` is empty. Capture screenshots of reader, a card/tag state, and summary/anchor return. Do not include secrets in any screenshot.

- [ ] **Step 5: Update Mac handoff and commit Task 9**

At the top of `HADNOFF_MAC.md`, record the final commit, that Task 6–9 use SwiftUI + TextKit + local Docker Supabase, the exact redacted build/test command shape, iPhone 16/iOS version, verified coverage, and exclusions (Task 10+, AI, Release CAFilter restriction). Do not alter the shared `docs/HANDOFF.md`.

```bash
git add ios_visual_prototype/DeepReadingVisualPrototype/Summary ios_visual_prototype/DeepReadingVisualPrototypeUITests ios_visual_prototype/DeepReadingVisualPrototypeTests ios_visual_prototype/DeepReadingVisualPrototype/DeepReadingVisualPrototypeApp.swift ios_visual_prototype/DeepReadingVisualPrototype/Reader/ReaderScreen.swift HADNOFF_MAC.md
git commit -m "feat: add native article asset summary"
```
