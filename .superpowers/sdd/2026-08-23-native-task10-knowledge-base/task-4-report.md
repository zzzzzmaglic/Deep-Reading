# Task 10.4 Report — Native Knowledge Base Navigation

Date: 2026-08-23

## Implemented

- Root native TabView with `.knowledge` selected by default.
- A single knowledge navigation path for collection, tag, reader, and summary destinations.
- Reader back pops only the reader route; summary “show in article” pops summary and replaces the reader route so the originating detail remains on the stack.
- Shared-client runtime construction and stable accessibility identifiers for the knowledge flow.
- `KnowledgeBaseFlowUITests` forwards public local Supabase values only at runtime; no value is stored in source.

## Verification

- TDD test source was added before the root navigation implementation. The initial requested simulator name was unavailable and the first red command could not reach XCTest; the actual device is `Deep Reading · iPhone 16` (iOS 26.5).
- `xcodebuild build` for that ARM64 simulator: passed (exit 0).
- Full `xcodebuild test`: passed (exit 0). The AppRuntime and all non-UI XCTest cases ran green; the two Task 6–9 UI tests and the new knowledge UI test explicitly skipped because the runner lacked public local Supabase environment values.
- An attempted live UI invocation read only the existing local runtime environment and did not reset data. It did not start the test because `supabase status -o env` returned nonzero with imgproxy/pooler stopped. Treat this as a live-verification caveat, not a product-code failure.
- `supabase db reset` was neither run nor requested.

## Remaining manual / live QA

- Run the new UI flow with runtime-only local public configuration: system tag → asset card → anchored reader → back to the same tag detail.
- Manually compare default Tab, 116 pt progressive blur, card geometry, and native glass controls with Figma 12–18.

## Extra implementation dependencies included with Task 10.4

- `KnowledgeHomeScreen.swift`: passes tag selection into the single root navigation path.
- `TagDetailScreen.swift`, `ReadingAssetListRow.swift`, and `ReadingAssetCard.swift`: provide the required stable asset/source/confirmation/dismiss accessibility surface without nested buttons.
- `SupabaseKnowledgeBaseRepository.swift`: exposes the minimal client-identity seam used to prove runtime repositories share the same `SupabaseClient`.
- `TagDetailCoordinatorTests.swift`: updates the established semantic confirmation test to the required stable knowledge-base IDs.

## Final review fix round 1

- Root cause: the prior UI seed argument only triggers inside `ReaderScreen`, but the released root correctly opens knowledge home. Consequently the test never mounted the reader and no seed RPC could run; tag IDs also incorrectly embedded a display name.
- Fix: in DEBUG only, `-ui-test-open-local-seed-reader` initializes the existing knowledge navigation path with a `.knowledge`-origin local seed reader route. The app still launches to the default knowledge home without that argument and in non-DEBUG builds. Both legacy reader UI helpers and the knowledge UI flow add the argument with `-ui-test-seed-highlight`.
- Fix: `knowledge-tag-{UUID}` now mirrors the stable UUID collection ID convention. The UI flow waits for the first UUID-backed system-tag row after returning to knowledge home, then verifies the tag detail survives the anchored reader round trip.
- Red/green evidence: new AppRuntime tests first failed to compile because the test-only path and identifier helpers did not exist; after the minimal implementation, focused AppRuntime/knowledge-UI compilation tests, full `xcodebuild test`, Debug `xcodebuild build`, and `git diff --check` all passed on the iPhone 16 iOS 26.5 simulator.

## Final rereview fix round 2

- Root cause: `testSummaryBackControlReturnsToTheReader` only waited for the seeded summary control to exist, whereas the real seed RPC intentionally leaves it disabled until completion. The second flow had a separate enabled predicate, creating divergent readiness contracts.
- Fix: both Task 6–9 UI flows now call one `seededSummaryButton(in:)` helper. It waits for `reader-open-summary` existence and then a real `enabled == 1` `XCTNSPredicateExpectation` before returning the control for tapping.
- Verification: full `xcodebuild test` exit 0, Debug `xcodebuild build` exit 0, and `git diff --check` exit 0. Without injected public local configuration, UI cases still explicitly skip; no live credentials or database reset were used.

## Final rereview fix round 3

- Root cause hypothesis: `TestAction` was configured to use scheme launch environment but declared no environment variables, so command-line build settings were not available to the UI test runner.
- Fix: the shared scheme now declares only two enabled placeholders: `SUPABASE_URL=$(SUPABASE_URL)` and `SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY)`. No actual value is present in the scheme or repository; a future invocation supplies both as transient Xcode build settings.
- Verification: no-configuration full XCTest and Debug build both exit 0; xcresult confirms the three intended UI flows skip solely for absent configuration. The one allowed local status read exited 1 while reporting imgproxy/pooler stopped, so it did not yield runtime values and neither live UI command started. This leaves the forwarding hypothesis unconfirmed; no fallback source, service start, key output, or database reset was attempted.
