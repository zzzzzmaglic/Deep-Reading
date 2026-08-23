# Task 10.3 report — 标签详情与阅读资产卡片复用

- Red: `ArticleAssetSummaryCoordinatorTests` now targets the missing shared `ReadingAssetListRowLayout`; new `TagDetailCoordinatorTests` cover normal/system bulk actions, newest-first ordering, standalone-note tag defaults, anchored knowledge route, mutation failure retention, and single-flight protection.
- Green implementation: extracted one `ReadingAssetListRow` and switched the summary to it; added `TagDetailCoordinator` and `TagDetailScreen`, which reuse `ReadingAssetCard`, `GlassIconControl`, and the reader progressive edges.
- XCTest: no reliable executed count. The focused `xcodebuild test` command initially failed before compilation because the sandbox could not write the SwiftPM manifest diagnostic cache. After approval, Xcode resolved packages but exited before producing build/test logs or the requested `.xcresult`; the existing app binary timestamp did not advance. Do not treat XCTest as green until this host-level Xcode interruption is resolved.
- Verified instead: `xcrun swiftc -parse` covered all changed/new Swift sources and both focused test sources; `plutil -lint` accepted `project.pbxproj`; `git diff --check` passed.
- Remaining concern: full XCTest and simulator visual acceptance remain blocked by the host Xcode execution interruption, not by a Supabase reset. `supabase/.branches/` and `supabase/.temp/` were not touched.

## Fix round 1

- Root cause: XCTest assertions are synchronous autoclosures, so they cannot await coordinator calls; Swift also cannot compare `[(UUID, [UUID])]` because that tuple does not conform to `Equatable`.
- Fix: awaited mutation outcomes into local values, then asserted them; changed recorded normal-tag request assertions to count, tag ID, and asset IDs.
- Green: focused iPhone 16 / iOS 26.5 XCTest ran 52 tests — 52 passed, 0 failed, 0 skipped. `git diff --check` passed.

## Fix round 2 — confirmation dialog review

- Replaced `TagDetailScreen`'s system SwiftUI alert with the existing `AssetCardConfirmationDialog` (313×202 Figma geometry). Both actions now retain selection/failure/single-flight semantics; cancel closes the overlay, success closes it after the RPC, and failure leaves it available for retry.
- Added `TagDetailSelectionConfirmation` test coverage for normal remove wording and system-delete destructive identifier. The system confirmation uses `tag-delete-confirm`; normal association removal uses `tag-remove-confirm` and explicitly states that the asset and other tags remain.
- Review decision: intentionally retained the generic “在文中显示” source action. The approved Figma 09 shared row already defines this action; `ReadingAsset` has no source-title field and fetching article titles would add a redundant query and expand this task’s scope. Changing it to a title would break the shared, accepted summary geometry and behavior.
- Green: focused iPhone 16 / iOS 26.5 XCTest ran 53 tests — 53 passed, 0 failed, 0 skipped. `git diff --check` passed.
