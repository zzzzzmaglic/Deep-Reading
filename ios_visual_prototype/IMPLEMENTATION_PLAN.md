# Deep Reading Native Visual Prototype — Implementation Plan

**Goal:** Create an entirely independent SwiftUI iPhone 16 / iOS 26 visual-validation app for Figma reader Frames 01–08, without changing the Flutter product or any backend.

**Constraints:**

- All files remain under `ios_visual_prototype/`.
- No network, Supabase, DeepSeek, Flutter imports, production feature work, Git commits, branches, or pushes.
- iOS deployment target is 26.0. Native floating controls use `GlassEffectContainer`, `.glassEffect(...)`, and `Glass.interactive()`.
- The local article is `1600-2100年的公司简史`. Paragraph one precedes the image; the cultural, commercial, gravity, and daily-life paragraphs follow it in order.

## File layout

- `DeepReadingVisualPrototype.xcodeproj/project.pbxproj` — standalone app target.
- `DeepReadingVisualPrototypeApp.swift` — SwiftUI app entry point.
- `ReaderPrototypeModel.swift` — local article and Frame 01–08 state model.
- `ReaderVisualTokens.swift` — Figma-derived dimensions, colors, typography, and edge treatments.
- `ReaderPrototypeView.swift` — scrolling reader, control visibility, and state routing.
- `ReaderGlassControls.swift` — iOS 26 native Liquid Glass control cluster.
- `ReaderOverlayViews.swift` — selection menu, underlines, asset card, tag sheets, and text entry.
- `Assets.xcassets/FourForces.imageset` — copied demonstration image only.
- `README.md` — exact build/run command and scope statement.

## Tasks

1. Create a minimal iOS 26 SwiftUI Xcode application with local Assets and a compile check.
2. Add local article/state data and test that Frame 01–08 state transitions remain within prototype scope.
3. Build Figma-metric reader content, native Liquid Glass floating controls, focus-mode transitions, and status-bar visibility.
4. Build visible overlays for Frames 03–08 using local state only; use Figma assets only where SF Symbols do not match.
5. Build for the existing iPhone 16 iOS 26 Simulator, take one screenshot per critical state, and leave the app on Frame 01.

## Verification

- Unit tests run in the prototype target only.
- `xcodebuild build` succeeds against the iPhone 16 iOS 26 Simulator.
- Simulator screenshots are compared with the read Figma Frames; differences are recorded in the final report.
