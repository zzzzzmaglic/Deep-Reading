# First Core User Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an iOS-only, online-first Deep Reading Demo covering the frozen reader, reading assets, knowledge-base browsing, and current-article AI companion flows.

**Architecture:** Build a Flutter application in `app/` with Riverpod feature state and `go_router` navigation. Supabase Postgres remains the only source of truth: public seed content is read through RLS, while private-asset writes use transaction-safe RPC functions; an Edge Function streams DeepSeek-V4-Pro responses without exposing credentials. SQLite is a read cache only, never an offline write queue.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Supabase Auth/Postgres/RLS/RPC/Edge Functions, Drift/SQLite, DeepSeek-V4-Pro SSE, GitHub Actions, Appetize.

## Global Constraints

- Build, visual QA, distribution, and final acceptance target **iOS only**; Android is not a supported or accepted target for this release.
- The Demo uses Supabase anonymous authentication, per-user RLS isolation, immutable seed articles, and a real AI gateway.
- `Postgres` is the only data source of truth. Drift/SQLite caches article reads only; it must not store asset edits, authentication state, a sync queue, or conflict state.
- The client must use RPC for all ReadingAsset, tag, and reading-progress writes. Do not let the client write those tables directly.
- A `ReadingAsset` is one entity with derived forms: `highlight_only`, `linked_note`, and `standalone_note`; cancelling a highlight hard-deletes its entire highlight-bearing asset, including any note.
- Every new ReadingAsset receives the locked `摘录与思考` tag. It cannot be removed, renamed, or deleted by a user.
- AI Companion context is limited to the current article. It does not perform internet or global knowledge-base search, and its session history exists only in the active reader instance.
- AI keys and Supabase service-role credentials must never be bundled in Flutter, Appetize artifacts, or client configuration.
- Required later scope, excluded from this plan: reading flow, completion reading and AI reading report, complete AI search, formal account/onboarding, offline editing/sync/conflict resolution, and App Store/TestFlight release.

## Planned File Structure

```text
app/
  lib/
    app.dart
    main.dart
    core/{network,storage,theme}/
    features/{auth,reader,reading_assets,knowledge_base,ai_companion}/
  test/
  integration_test/
supabase/
  migrations/
  functions/ai-companion/
  tests/
.github/workflows/
docs/demo-environment.md
```

---

### Task 1: Bootstrap the Flutter workspace and continuous verification

**Files:**
- Create: `app/` Flutter project files, `app/lib/main.dart`, `app/lib/app.dart`
- Create: `app/analysis_options.yaml`, `app/test/app_smoke_test.dart`
- Create: `.github/workflows/check.yml`, `.gitignore`, `README.md`

**Interfaces:**
- Produces `DeepReadingApp`, the application root used by all widget and integration tests.
- Produces the `app/` working-directory contract for every remaining Flutter task.

- [ ] **Step 1: Write the failing smoke test**

```dart
testWidgets('boots the Deep Reading application', (tester) async {
  await tester.pumpWidget(const DeepReadingApp());
  expect(find.text('Deep Reading'), findsOneWidget);
});
```

- [ ] **Step 2: Run the smoke test to verify it fails before the app root exists**

Run: `flutter test test/app_smoke_test.dart`

Expected: FAIL because `DeepReadingApp` is not defined.

- [ ] **Step 3: Create the app and quality baseline**

```bash
flutter create --platforms=ios app
cd app
flutter pub add flutter_riverpod go_router supabase_flutter drift drift_flutter shared_preferences flutter_cache_manager http uuid
flutter pub add --dev build_runner drift_dev
```

Replace `app/lib/main.dart` with a `ProviderScope` that runs `DeepReadingApp`; define `DeepReadingApp` in `app/lib/app.dart` as a `MaterialApp.router` with `title: 'Deep Reading'`. Configure `analysis_options.yaml` to include `package:flutter_lints/flutter.yaml` and enable `always_declare_return_types`, `avoid_dynamic_calls`, and `unawaited_futures`. Add a root `README.md` describing `cd app`, `flutter pub get`, `flutter test`, and the iOS-only constraint.

- [ ] **Step 4: Add the CI check workflow and make the smoke test pass**

```yaml
name: Check
on: [pull_request, push]
jobs:
  flutter:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
```

Run: `cd app; dart format .; flutter analyze; flutter test test/app_smoke_test.dart`

Expected: all commands pass and the app renders `Deep Reading`.

- [ ] **Step 5: Commit the foundation**

```bash
git add app .github/workflows/check.yml .gitignore README.md
git commit -m "chore: bootstrap Flutter app and CI checks"
```

### Task 2: Define Supabase schema, seed content, and RLS isolation

**Files:**
- Create: `supabase/config.toml`
- Create: `supabase/migrations/202608070001_initial_schema.sql`
- Create: `supabase/seed.sql`
- Create: `supabase/tests/001_rls_isolation.test.sql`

**Interfaces:**
- Produces immutable `articles`, `article_blocks`, `collections`, and `article_collections` seed-read tables.
- Produces private `reading_progress`, `reading_assets`, `asset_anchors`, `tags`, and `asset_tags` tables with `owner_id = auth.uid()` RLS.
- Defines the per-owner system tag by `tags.is_system = true` and `tags.name = '摘录与思考'`.

- [ ] **Step 1: Write RLS tests before defining policies**

```sql
select plan(2);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is((select count(*) from public.reading_assets), 1::bigint, 'owner sees its asset');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select is((select count(*) from public.reading_assets), 0::bigint, 'other owner cannot see the asset');
select * from finish();
```

- [ ] **Step 2: Run the database test and verify it fails**

Run: `supabase start && supabase db reset && supabase test db`

Expected: FAIL because the tables and policies do not exist.

- [ ] **Step 3: Implement the schema and policies**

Create the migration with UUID primary keys, UTC `created_at`/`updated_at` timestamps, stable `article_blocks.position`, and `articles.content_checksum`. `asset_anchors` must contain `article_id`, start/end block UUIDs, start/end UTF-16 offsets, `selected_text`, and `content_checksum`. Add a check constraint requiring either a non-null `note_content` or one anchor; do not add an `asset_type` column because asset form is derived.

Enable RLS on every private table. Add policies that allow direct `select` only when `owner_id = auth.uid()`, and deny direct insert/update/delete. Allow all authenticated users to select seed articles, blocks, collections, and article-collection rows; deny modification of seed content. Seed at least three immutable Chinese articles, their ordered blocks, and `往期推文`; create the private locked `摘录与思考` tag lazily for each owner from the asset RPC, rather than as a shared seed row.

- [ ] **Step 4: Re-run the database test and inspect the schema**

Run: `supabase db reset && supabase test db`

Expected: PASS. The RLS test sees exactly its own seeded asset and cannot see another anonymous user's asset.

- [ ] **Step 5: Commit the database foundation**

```bash
git add supabase/config.toml supabase/migrations supabase/seed.sql supabase/tests
git commit -m "feat: add Supabase schema seed data and RLS"
```

### Task 3: Add transaction-safe RPC operations for assets, tags, and progress

**Files:**
- Modify: `supabase/migrations/202608070001_initial_schema.sql`
- Create: `supabase/tests/002_asset_rpc.test.sql`
- Create: `app/lib/features/reading_assets/domain/reading_asset.dart`
- Create: `app/lib/features/reading_assets/data/reading_asset_repository.dart`
- Create: `app/test/features/reading_assets/domain/reading_asset_test.dart`

**Interfaces:**
- Produces RPC functions `create_highlight_asset`, `create_standalone_note`, `update_reading_asset`, `set_asset_tags`, `delete_reading_asset`, and `upsert_reading_progress`.
- Produces `ReadingAssetKind deriveReadingAssetKind({required TextAnchor? anchor, required String? noteContent})`.
- `update_reading_asset` updates a pure highlight into a linked note in place, preserving the asset UUID.

- [ ] **Step 1: Write failing database and Dart domain tests**

```dart
expect(deriveReadingAssetKind(anchor: anchor, noteContent: null), ReadingAssetKind.highlightOnly);
expect(deriveReadingAssetKind(anchor: anchor, noteContent: '想继续研究'), ReadingAssetKind.linkedNote);
expect(deriveReadingAssetKind(anchor: null, noteContent: '独立想法'), ReadingAssetKind.standaloneNote);
```

In `002_asset_rpc.test.sql`, assert a created highlight has the locked tag, adding note text preserves its asset ID, and deleting it removes the anchor and every `asset_tags` row.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `supabase db reset && supabase test db; cd app; flutter test test/features/reading_assets/domain/reading_asset_test.dart`

Expected: FAIL because the RPC functions and Dart asset model do not exist.

- [ ] **Step 3: Implement atomic RPCs and the client repository**

Implement every SQL function as `security definer`, set a safe `search_path`, read `auth.uid()` into a local variable, and reject null identity. `create_highlight_asset` inserts both asset and anchor, then gets or creates that owner's locked `摘录与思考` tag and attaches it in one transaction. `set_asset_tags` rejects removal of the locked relation; `delete_reading_asset` deletes the asset so foreign-key cascades remove anchors/tags. `update_reading_asset` accepts a nullable note value but rejects an anchorless empty-note asset.

Define immutable Dart `TextAnchor`, `ReadingAsset`, `Tag`, and `ReadingAssetKind`; implement `SupabaseReadingAssetRepository` to call only the named RPCs for writes. Keep its read methods typed and RLS-backed.

- [ ] **Step 4: Run the complete asset test set**

Run: `supabase db reset && supabase test db; cd app; flutter test test/features/reading_assets/domain/reading_asset_test.dart`

Expected: PASS. Confirm no test uses direct table writes from the Flutter repository.

- [ ] **Step 5: Commit asset business rules**

```bash
git add supabase app/lib/features/reading_assets app/test/features/reading_assets
git commit -m "feat: add atomic reading asset RPC operations"
```

### Task 4: Implement the AI gateway with streamed, bounded current-article context

**Files:**
- Create: `supabase/functions/ai-companion/index.ts`
- Create: `supabase/functions/ai-companion/context.ts`
- Create: `supabase/functions/ai-companion/context_test.ts`
- Create: `supabase/functions/ai-companion/deno.json`
- Create: `docs/demo-environment.md`

**Interfaces:**
- Accepts `POST /functions/v1/ai-companion` body `{ articleId, requestType, question, anchor? }`.
- Emits SSE events `started`, `delta`, `completed`, and `error`.
- Produces `buildArticleContext(articleBlocks, anchor)` using full text for short articles and a bounded anchor-neighbourhood for long articles.

- [ ] **Step 1: Write the context-boundary test**

```ts
Deno.test('long article context contains the selected block and neighbours only', () => {
  const context = buildArticleContext(blocksOf(20), anchorAt(10));
  assert(context.includes('block-9'));
  assert(context.includes('block-10'));
  assert(context.includes('block-11'));
  assert(!context.includes('block-0'));
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `deno test supabase/functions/ai-companion/context_test.ts`

Expected: FAIL because the context module has not been created.

- [ ] **Step 3: Implement the Edge Function and abuse controls**

Validate the caller JWT with Supabase Auth, fetch article blocks server-side by `articleId`, and ignore any article text supplied by the client. Validate `requestType` against `question`, `selection_explain`, `highlight_explain`, and `preset_term_explain`. Enforce a per-anonymous-user request window, maximum output token count, and deployment feature switch before calling DeepSeek.

Call DeepSeek-V4-Pro with `stream: true`; use environment variables `DEEPSEEK_API_KEY`, `DEEPSEEK_MODEL=DeepSeek-V4-Pro`, `AI_ENABLED`, `AI_MAX_OUTPUT_TOKENS`, and `AI_REQUESTS_PER_HOUR`. Transform upstream chunks to only the four declared event names, forward cancellation through `AbortController`, and never emit model reasoning. Log only anonymous request ID, status/error code, elapsed time, token count, and budget event.

- [ ] **Step 4: Verify function tests and local behavior**

Run: `deno test supabase/functions/ai-companion/context_test.ts && supabase functions serve ai-companion --no-verify-jwt`

Expected: the test passes and an authenticated request begins with `event: started`, streams `event: delta`, then ends with `event: completed` or typed `event: error`.

- [ ] **Step 5: Commit the streaming gateway**

```bash
git add supabase/functions/ai-companion docs/demo-environment.md
git commit -m "feat: add bounded AI companion streaming gateway"
```

### Task 5: Build app services, anonymous bootstrap, cache, and navigation contracts

**Files:**
- Create: `app/lib/core/network/supabase_client_provider.dart`
- Create: `app/lib/core/storage/app_database.dart`
- Create: `app/lib/core/storage/preference_store.dart`
- Create: `app/lib/features/auth/data/anonymous_auth_service.dart`
- Create: `app/lib/core/router/app_router.dart`
- Create: `app/test/features/auth/data/anonymous_auth_service_test.dart`
- Create: `app/test/core/router/app_router_test.dart`

**Interfaces:**
- Produces `anonymousAuthBootstrapProvider` that calls `signInAnonymously()` only when no session exists.
- Produces `/reader/:articleId`, `/knowledge`, `/knowledge/collections/:collectionId`, `/knowledge/tags/:tagId`, and `/reader/:articleId/summary`.
- Reader route extra is `ReaderRouteContext({required ReaderOrigin origin, String? anchorId})` where origin is `feed` or `knowledge`.

- [ ] **Step 1: Write failing authentication and routing tests**

```dart
test('anonymous bootstrap does not replace an existing session', () async {
  final client = FakeSupabaseClient.withSession();
  await AnonymousAuthService(client).ensureSession();
  expect(client.anonymousSignInCalls, 0);
});
testWidgets('reader route preserves an anchor in its route context', (tester) async {
  await tester.pumpWidget(DeepReadingApp.routerForTest('/reader/a-1', anchorId: 'anchor-1'));
  expect(find.byKey(const Key('reader-anchor-anchor-1')), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd app; flutter test test/features/auth/data/anonymous_auth_service_test.dart test/core/router/app_router_test.dart`

Expected: FAIL because bootstrap, routes, and route context are absent.

- [ ] **Step 3: Implement the service layer and cache boundary**

Initialize `Supabase.initialize` from `SUPABASE_URL` and `SUPABASE_ANON_KEY`; reject missing values in debug mode. Build Drift tables containing only cached article metadata, blocks, cache version, and expiry; expose `ArticleCache.readThenRefresh(articleId)` that returns cached content immediately and replaces it after successful Supabase read. Persist only reader font size and theme with `SharedPreferencesAsync`.

Implement go_router with the declared contracts. Summary-to-reader and tag-detail-to-reader use replacement navigation so summary is not left on the back stack. Sheets and dialogs remain overlay routes or widget-local state and restore reader scroll/control state when dismissed.

- [ ] **Step 4: Run tests and static analysis**

Run: `cd app; dart format .; flutter analyze; flutter test test/features/auth/data/anonymous_auth_service_test.dart test/core/router/app_router_test.dart`

Expected: PASS. Inspect `app_database.dart` to ensure it has no asset, tag, auth, draft, queue, or conflict table.

- [ ] **Step 5: Commit infrastructure and navigation**

```bash
git add app/lib/core app/lib/features/auth app/test/features/auth app/test/core
git commit -m "feat: add anonymous bootstrap cache and navigation contracts"
```

### Task 6: Implement the iOS reader, preferences, progress, and anchor positioning

**Files:**
- Create: `app/lib/features/reader/domain/article.dart`
- Create: `app/lib/features/reader/data/article_repository.dart`
- Create: `app/lib/features/reader/presentation/reader_screen.dart`
- Create: `app/lib/features/reader/presentation/reader_style_sheet.dart`
- Create: `app/lib/features/reader/presentation/reader_controller.dart`
- Create: `app/test/features/reader/presentation/reader_screen_test.dart`
- Create: `app/test/features/reader/presentation/reader_style_sheet_test.dart`

**Interfaces:**
- Produces `ReaderScreen(articleId, ReaderRouteContext)` and keys `reader-anchor-<anchorId>` for anchor target blocks.
- Produces `ReaderController.updateProgress(blockId, utf16Offset)` calling `upsert_reading_progress` only while online.
- Produces five font-size preferences and `ReaderThemeMode.light`, `.dark`, `.system`.

- [ ] **Step 1: Write failing reader widget tests**

```dart
testWidgets('reader scrolls the requested anchor into view', (tester) async {
  await pumpReader(tester, anchorId: 'anchor-2');
  expect(find.byKey(const Key('reader-anchor-anchor-2')), findsOneWidget);
});
testWidgets('font controls stop at the configured boundary', (tester) async {
  await pumpStyleSheet(tester, fontIndex: 4);
  expect(tester.widget<IconButton>(find.byKey(const Key('increase-font'))).onPressed, isNull);
});
```

- [ ] **Step 2: Run the reader tests to verify they fail**

Run: `cd app; flutter test test/features/reader/presentation/reader_screen_test.dart test/features/reader/presentation/reader_style_sheet_test.dart`

Expected: FAIL because the reader screen and style sheet are absent.

- [ ] **Step 3: Implement reader rendering and state restoration**

Map immutable article blocks into a `CustomScrollView` with stable block keys, iOS-safe-area toolbar controls, default 21 pt body text, and 4 pt base spacing. Restore a saved block/offset normally; when the route contains an anchor, position that anchor instead. Implement controls-hidden and controls-visible states without allowing top/bottom overlay regions to consume text-selection gestures.

Add a Bottom Sheet containing only five font sizes and three themes. Apply every change immediately and store it through `PreferenceStore`; no confirm/cancel action. Debounce progress writes and display an inline retryable offline error without an offline queue.

- [ ] **Step 4: Run reader tests on the iOS target where available**

Run: `cd app; flutter test test/features/reader/presentation && flutter analyze`

Expected: PASS. On macOS, also run `flutter run -d ios-simulator` and manually verify default text, theme change, and anchor positioning.

- [ ] **Step 5: Commit the reader baseline**

```bash
git add app/lib/features/reader app/test/features/reader
git commit -m "feat: implement iOS reader preferences and anchors"
```

### Task 7: Add text selection, highlights, and standalone-note creation

**Files:**
- Create: `app/lib/features/reader/presentation/selection/reader_selection_adapter.dart`
- Create: `app/lib/features/reader/presentation/selection/reader_context_menu.dart`
- Create: `app/lib/features/reader/presentation/selection/selection_to_anchor.dart`
- Modify: `app/lib/features/reader/presentation/reader_screen.dart`
- Create: `app/test/features/reader/presentation/selection_to_anchor_test.dart`
- Create: `app/test/features/reader/presentation/reader_context_menu_test.dart`

**Interfaces:**
- Produces `TextAnchor selectionToAnchor(Article article, ReaderSelection selection)` with UTF-16 offsets.
- Context actions are `highlight`, `openAssetCard`, `explainWithAi`, and `copy`.
- `highlight` calls `ReadingAssetRepository.createHighlight(anchor)` and updates the reader without leaving it.

- [ ] **Step 1: Write failing selection and menu tests**

```dart
test('cross-block selection produces two stable block endpoints', () {
  final anchor = selectionToAnchor(article, selectionAcrossBlocks('b-1', 2, 'b-2', 4));
  expect(anchor.start.blockId, 'b-1');
  expect(anchor.end.blockId, 'b-2');
  expect(anchor.start.utf16Offset, 2);
});
testWidgets('highlight action creates an asset and renders it highlighted', (tester) async {
  await pumpSelectableReader(tester);
  await tester.tap(find.text('划线'));
  expect(fakeAssets.createdAnchors, hasLength(1));
  expect(find.byKey(const Key('highlighted-block-b-1')), findsOneWidget);
});
```

- [ ] **Step 2: Run the selection tests to verify they fail**

Run: `cd app; flutter test test/features/reader/presentation/selection_to_anchor_test.dart test/features/reader/presentation/reader_context_menu_test.dart`

Expected: FAIL because selection conversion and custom actions do not exist.

- [ ] **Step 3: Implement selection with an iOS fallback boundary**

Use `SelectionArea`/`SelectableRegion` and a custom toolbar adapter; derive offsets from the Dart UTF-16 indexes used by rendered blocks. Render persisted anchors as highlights, including multi-block ranges. Implement clipboard copy, RPC-backed highlight creation, asset-card open, and AI-sheet request drafts.

Keep all behavior behind `ReaderSelectionAdapter`. Declare but do not implement `IosNativeSelectionAdapter`; only implement it if iOS Simulator acceptance exposes an actual selection incompatibility. Add the reader's standalone-note action, opening a blank asset-card draft.

- [ ] **Step 4: Run tests and validate long-press behavior**

Run: `cd app; flutter test test/features/reader/presentation/selection_to_anchor_test.dart test/features/reader/presentation/reader_context_menu_test.dart`

Expected: PASS. On iOS Simulator, long-press text, make a multi-block selection, create a highlight, reopen the article, and confirm it remains.

- [ ] **Step 5: Commit text selection and asset entry points**

```bash
git add app/lib/features/reader app/test/features/reader
git commit -m "feat: add reader selection highlights and note entry"
```

### Task 8: Implement ReadingAsset cards, drafts, tags, and destructive actions

**Files:**
- Create: `app/lib/features/reading_assets/presentation/reading_asset_card.dart`
- Create: `app/lib/features/reading_assets/presentation/reading_asset_editor.dart`
- Create: `app/lib/features/reading_assets/presentation/tag_management_sheet.dart`
- Create: `app/lib/features/reading_assets/presentation/delete_asset_dialog.dart`
- Create: `app/lib/features/reading_assets/presentation/asset_editor_controller.dart`
- Create: `app/test/features/reading_assets/presentation/asset_editor_controller_test.dart`
- Create: `app/test/features/reading_assets/presentation/reading_asset_card_test.dart`

**Interfaces:**
- Produces `AssetEditorDraft` with `originalAsset`, `noteContent`, and `selectedTagIds`.
- Produces `hasUnsavedChanges` and `save()`; only `save()` invokes update/tag RPCs in edit mode.
- View-mode tag confirmation saves immediately; edit-mode tag changes stay in the draft until `save()`.

- [ ] **Step 1: Write failing draft and card tests**

```dart
test('adding note content converts a highlight in the same draft asset', () {
  final draft = AssetEditorDraft.fromHighlight(assetId: 'asset-1');
  expect(draft.withNote('想法').assetId, 'asset-1');
  expect(draft.withNote('想法').kind, ReadingAssetKind.linkedNote);
});
testWidgets('locked tag cannot be deselected', (tester) async {
  await pumpTagSheet(tester, lockedTagSelected: true);
  await tester.tap(find.text('摘录与思考'));
  expect(fakeRepository.removedLockedTag, isFalse);
});
```

- [ ] **Step 2: Run the asset-card tests to verify they fail**

Run: `cd app; flutter test test/features/reading_assets/presentation/asset_editor_controller_test.dart test/features/reading_assets/presentation/reading_asset_card_test.dart`

Expected: FAIL because draft handling and card UI do not exist.

- [ ] **Step 3: Implement card states and mutations**

Render one card shell for all three forms: highlight area above and note area below when anchored; note only when standalone. In view mode, show “添加笔记内容” for a pure highlight and enter edit mode when tapped. Limit visible highlight preview and provide an internal full-content detail view.

Implement focus on edit entry, tag selection/creation, discard-edit confirmation, and delete confirmation. Outside taps/drags close only an unmodified card; edited drafts ask to discard. View-mode tag confirmation calls `set_asset_tags` immediately. Edit-mode tag changes remain local until “完成编辑”. Deleting a highlight-bearing asset removes the reader highlight after RPC success.

- [ ] **Step 4: Run widget tests for all asset forms**

Run: `cd app; flutter test test/features/reading_assets/presentation`

Expected: PASS for pure highlight, linked note, standalone note, locked-tag protection, draft discard, and delete confirmation.

- [ ] **Step 5: Commit ReadingAsset cards**

```bash
git add app/lib/features/reading_assets app/test/features/reading_assets
git commit -m "feat: implement reading asset cards tags and drafts"
```

### Task 9: Implement current-article asset summary and anchor-return behavior

**Files:**
- Create: `app/lib/features/reader/presentation/article_asset_summary_screen.dart`
- Create: `app/lib/features/reader/presentation/article_asset_summary_controller.dart`
- Create: `app/test/features/reader/presentation/article_asset_summary_screen_test.dart`
- Modify: `app/lib/core/router/app_router.dart`

**Interfaces:**
- Produces a current-article summary list of all derived ReadingAsset forms.
- `showInArticle(asset)` replaces the summary with `/reader/:articleId` and `ReaderRouteContext(anchorId: asset.anchorId, origin: feed)`.
- `deleteSelectedAssets(Set<String>)` refreshes the list only after all RPC deletions succeed.

- [ ] **Step 1: Write failing navigation and multi-select tests**

```dart
testWidgets('show in article replaces summary and navigates to the anchor', (tester) async {
  await pumpSummary(tester);
  await tester.tap(find.text('在文中显示').first);
  expect(router.location, '/reader/article-1');
  expect(readerContext.anchorId, 'anchor-1');
});
test('delete selected assets refreshes after every deletion succeeds', () async {
  await controller.deleteSelectedAssets({'a1', 'a2'});
  expect(repository.deletedIds, containsAll(<String>['a1', 'a2']));
});
```

- [ ] **Step 2: Run summary tests to verify they fail**

Run: `cd app; flutter test test/features/reader/presentation/article_asset_summary_screen_test.dart`

Expected: FAIL because summary route and controller do not exist.

- [ ] **Step 3: Implement the summary list and return contract**

List current-article highlights, linked notes, and standalone notes in one screen. Each item opens the same ReadingAsset card; only anchored assets render “在文中显示”. Add right-swipe selection with neutral selected state, a bottom destructive control only while selection is non-empty, and permanent-delete confirmation. Use replacement navigation for “在文中显示” so iOS back returns to the reader origin rather than summary.

- [ ] **Step 4: Run tests and a route regression walk-through**

Run: `cd app; flutter test test/features/reader/presentation/article_asset_summary_screen_test.dart`

Expected: PASS. Verify reader → summary → “在文中显示” → iOS back returns to the original feed context, not summary.

- [ ] **Step 5: Commit the current-article summary**

```bash
git add app/lib/features/reader app/lib/core/router app/test/features/reader
git commit -m "feat: add current article asset summary"
```

### Task 10: Implement knowledge-base browsing and scoped asset management

**Files:**
- Create: `app/lib/features/knowledge_base/data/knowledge_base_repository.dart`
- Create: `app/lib/features/knowledge_base/presentation/knowledge_home_screen.dart`
- Create: `app/lib/features/knowledge_base/presentation/collection_detail_screen.dart`
- Create: `app/lib/features/knowledge_base/presentation/tag_detail_screen.dart`
- Create: `app/lib/features/knowledge_base/presentation/knowledge_base_controller.dart`
- Create: `app/test/features/knowledge_base/presentation/knowledge_home_screen_test.dart`
- Create: `app/test/features/knowledge_base/presentation/tag_detail_screen_test.dart`

**Interfaces:**
- Produces `/knowledge`, `/knowledge/collections/:collectionId`, and `/knowledge/tags/:tagId` views.
- `removeAssetsFromTag(tagId, assetIds)` removes ordinary tag relations; locked-tag removal calls `deleteReadingAsset` after confirmation.
- `openArticleFromTag(asset)` uses `ReaderRouteContext(origin: knowledge, anchorId: asset.anchorId)`.

- [ ] **Step 1: Write failing browse and tag-action tests**

```dart
testWidgets('knowledge home restores collapsed groups on re-entry', (tester) async {
  await pumpKnowledgeHome(tester);
  await tester.tap(find.byKey(const Key('expand-tags')));
  await leaveAndReturnToKnowledgeHome(tester);
  expect(find.text('标签 6 条'), findsNothing);
});
test('locked tag bulk action deletes assets instead of only unlinking them', () async {
  await controller.removeAssetsFromTag(lockedTagId, {'asset-1'});
  expect(repository.deletedAssetIds, contains('asset-1'));
});
```

- [ ] **Step 2: Run knowledge-base tests to verify they fail**

Run: `cd app; flutter test test/features/knowledge_base/presentation/knowledge_home_screen_test.dart test/features/knowledge_base/presentation/tag_detail_screen_test.dart`

Expected: FAIL because the views and controller do not exist.

- [ ] **Step 3: Implement browsing and only approved management paths**

Build two grouped lists for collections and tags, defaulting to collapsed and showing at most five entries. Render `往期推文` and `摘录与思考` as fixed first entries. Implement collection-detail article browsing and normal-collection multi-select removal of article associations. Implement tag-detail asset browsing, source-article anchor navigation, ordinary-tag multi-select removal, locked-tag permanent asset deletion, and standalone-note creation from a tag with the current tag preselected.

Do not implement general collection creation, reorder, rename, deletion, or unapproved knowledge-management exception branches. Keep those UI affordances absent.

- [ ] **Step 4: Run knowledge-base tests and verify origins**

Run: `cd app; flutter test test/features/knowledge_base/presentation && flutter analyze`

Expected: PASS. On iOS Simulator, open an article from a collection and a source article from a tag, then use back; each returns to its detail page.

- [ ] **Step 5: Commit knowledge-base browsing**

```bash
git add app/lib/features/knowledge_base app/test/features/knowledge_base
git commit -m "feat: add knowledge base browsing and tag asset actions"
```

### Task 11: Implement the AI Companion Bottom Sheet and client SSE lifecycle

**Files:**
- Create: `app/lib/features/ai_companion/domain/ai_message.dart`
- Create: `app/lib/features/ai_companion/data/ai_companion_repository.dart`
- Create: `app/lib/features/ai_companion/presentation/ai_companion_sheet.dart`
- Create: `app/lib/features/ai_companion/presentation/ai_companion_controller.dart`
- Create: `app/lib/features/ai_companion/presentation/recommended_questions.dart`
- Create: `app/test/features/ai_companion/data/ai_companion_repository_test.dart`
- Create: `app/test/features/ai_companion/presentation/ai_companion_sheet_test.dart`

**Interfaces:**
- `AiCompanionRepository.stream(AiRequest)` yields `started`, `delta(text)`, `completed`, or `error(code, message)`.
- `AiCompanionController` keeps `List<AiMessage>` in memory only and exposes `send`, `stop`, `retryLastFailed`, and `disposeSession`.
- `AiRequest` accepts article ID, request type, question, and optional `TextAnchor`; it never contains article body text.

- [ ] **Step 1: Write failing stream and UI-state tests**

```dart
test('stop retains emitted content and cancels the stream subscription', () async {
  await controller.send(question('解释一下'));
  fakeStream.emitDelta('已生成部分');
  await controller.stop();
  expect(controller.messages.last.text, '已生成部分');
  expect(fakeStream.cancelled, isTrue);
});
testWidgets('generating shows stop while input remains editable', (tester) async {
  await pumpGeneratingSheet(tester);
  expect(find.byKey(const Key('ai-stop')), findsOneWidget);
  await tester.enterText(find.byKey(const Key('ai-input')), '下一条问题');
  expect(find.text('下一条问题'), findsOneWidget);
});
```

- [ ] **Step 2: Run AI tests to verify they fail**

Run: `cd app; flutter test test/features/ai_companion/data/ai_companion_repository_test.dart test/features/ai_companion/presentation/ai_companion_sheet_test.dart`

Expected: FAIL because SSE parser, controller, and sheet do not exist.

- [ ] **Step 3: Implement client streaming and approved triggers**

Parse Edge Function events, create an AI placeholder after `started`, append `delta`, resolve on `completed`, and convert `error` to an AI-side retryable message. Use a cancellable HTTP request so stop cancels the request and preserves emitted text. Keep input editable during generation; show stop only in place of send/voice and restore send or voice based on input after completion or stop.

Render a 60%-height Bottom Sheet that expands with keyboard, user messages on the right, AI messages on the left, reference chips for selected/highlighted text, and opaque lower input masking. Open the same in-memory session from reader AI, selected text, highlight text, and preset difficult terms. Empty sessions show at most three “你可以这样问” recommendations; completed AI messages show at most three “你还可以问” questions. Destroy session on reader disposal, article change, or app termination; never persist it.

- [ ] **Step 4: Run AI tests and verify error paths**

Run: `cd app; flutter test test/features/ai_companion && flutter analyze`

Expected: PASS. On iOS Simulator, verify normal question, reference explanation, stop mid-stream, retry after a simulated error, and empty session after reopening a disposed reader.

- [ ] **Step 5: Commit AI Companion**

```bash
git add app/lib/features/ai_companion app/test/features/ai_companion
git commit -m "feat: add streaming AI companion sheet"
```

### Task 12: Produce the isolated Demo deployment and end-to-end acceptance suite

**Files:**
- Create: `.github/workflows/demo-ios.yml`
- Create: `app/integration_test/core_path_test.dart`
- Create: `scripts/upload_appetize.sh`
- Modify: `docs/demo-environment.md`, `README.md`

**Interfaces:**
- A `workflow_dispatch` or `demo-*` tag creates an iOS Simulator `.app`, uploads it to Appetize, and reports build number plus commit SHA.
- The integration suite covers reader selection/asset lifecycle, knowledge browsing, AI stop/retry, and anonymous-user isolation setup.

- [ ] **Step 1: Write the failing core-path integration test**

```dart
testWidgets('anonymous visitor can create, edit, locate, and delete a reading asset', (tester) async {
  await launchDemo(tester);
  await selectTextAndTap(tester, action: '划线');
  await openFirstHighlightCard(tester);
  await enterAndSaveNote(tester, '需要复读');
  await tapShowInArticle(tester);
  expect(find.byKey(const Key('reader-anchor-first-highlight')), findsOneWidget);
  await cancelHighlightAndConfirm(tester);
  expect(find.byKey(const Key('reader-anchor-first-highlight')), findsNothing);
});
```

- [ ] **Step 2: Run it to verify it fails before full implementation**

Run: `cd app; flutter test integration_test/core_path_test.dart`

Expected: FAIL until Tasks 1–11 are complete and the test harness uses local Supabase.

- [ ] **Step 3: Implement the iOS Demo workflow and secure upload script**

Create `.github/workflows/demo-ios.yml` on `macos-latest`: checkout, stable Flutter, `flutter pub get`, format check, analyze, test, then `flutter build ios --simulator --release`. Archive `app/build/ios/iphonesimulator/Runner.app` as a zip artifact.

`scripts/upload_appetize.sh` requires `APPETIZE_API_TOKEN` and `APPETIZE_PUBLIC_KEY` from GitHub Secrets, uploads the zip through Appetize's current API, and prints only the public URL, commit SHA, and build number. Never echo tokens. Configure GitHub Environment `demo` with Supabase URL/anon key, Edge Function feature switch, and bounded AI budget; keep the DeepSeek key only in Supabase Function secrets. Document local setup, reset commands, required secrets, reset behavior, and AI disable switch in `docs/demo-environment.md`.

- [ ] **Step 4: Execute automated and manual acceptance**

Run: `cd app; flutter test; flutter test integration_test/core_path_test.dart`

Expected: PASS against local Supabase. On macOS, publish a Demo build and walk both iOS Simulator and Appetize through: anonymous startup, cross-block highlight, linked-note edit, tag protection, knowledge browsing, source-anchor return, AI stop/retry, and reopening the Demo with isolated fresh anonymous data.

- [ ] **Step 5: Commit delivery automation and record the release candidate**

```bash
git add .github/workflows/demo-ios.yml app/integration_test scripts/upload_appetize.sh docs/demo-environment.md README.md
git commit -m "ci: publish iOS simulator demo to Appetize"
```

## Self-Review

### Spec coverage

- Flutter iOS-only, Riverpod, go_router, Drift read cache, Supabase/RLS/RPC, Edge Function, DeepSeek streaming, anonymous Demo, and Appetize delivery are covered by Tasks 1–5 and 12.
- Reader controls, anchors, style settings, progress, and selection fallback boundary are covered by Tasks 6–7.
- ReadingAsset forms, locked tags, atomic writes, cards, drafts, and deletion are covered by Tasks 2–3 and 8.
- Current-article summary and navigation replacement are covered by Task 9; knowledge-base browsing and approved actions by Task 10.
- AI streaming, stop/retry, session lifetime, and recommendation UI are covered by Tasks 4 and 11.
- Unit, widget, integration, iOS Simulator, and Appetize checks are required by Tasks 1–12.

### Deliberate exclusions

This plan does not implement reading flow, completion-reading state or AI reading reports, full AI search, formal accounts, offline write/sync/conflict handling, production content ingestion, TestFlight, or App Store distribution.

### Consistency check

`TextAnchor`, `ReadingAssetKind`, RPC names, `ReaderRouteContext`, and `AiCompanionRepository.stream` are introduced before later tasks consume them. All private writes use the Task 3 repository/RPC boundary, and no task introduces a local source of truth or persisted AI session.
