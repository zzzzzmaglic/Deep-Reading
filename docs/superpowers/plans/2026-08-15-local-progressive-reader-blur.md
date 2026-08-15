# Local Progressive Reader Blur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independently implemented, real-time progressive blur to the top 148pt of the SwiftUI reader prototype, while retaining the current 98pt native bottom soft edge.

**Architecture:** The reader remains a three-layer ZStack: scrollable article content at the back, a non-interactive top overlay in the middle, and Liquid Glass controls at the front. The local overlay uses a UIKit `UIVisualEffectView` backdrop layer configured with the same variable-radius blur mechanism studied in the reference repository, then adds a SwiftUI background-color tint gradient. It is not an external package and does not alter Flutter or production paths.

**Tech Stack:** Swift 5.9+, SwiftUI, UIKit, Core Image, QuartzCore; iPhone 16 iOS 26 Simulator.

## Global Constraints

- Touch only `ios_visual_prototype/` and this implementation plan.
- Do not add, download, or link `ProgressiveBlurHeader` or `VariableBlur` as an external dependency.
- Use the local prototype only; do not modify Flutter, Supabase, migrations, seed data, or release targets.
- Keep the top overlay height exactly 148pt and the bottom edge allocation exactly 98pt.
- The top overlay must be non-interactive and disappear together with reader chrome; the AI control remains visible in focused state.
- Do not commit or push as part of this implementation plan.

---

### Task 1: Define progressive-edge geometry and prove the sizing contract

**Files:**
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/ReaderVisualTokens.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototypeTests/ReaderPrototypeModelTests.swift`

**Interfaces:**
- Produces: `ReaderVisualTokens.topProgressiveBlurHeight: CGFloat` and `ReaderVisualTokens.bottomSoftEdgeHeight: CGFloat`.
- Consumed by: `ReaderPrototypeView` and `ReaderProgressiveBlurView` in Task 2.

- [ ] **Step 1: Write the failing test**

```swift
func testReaderEdgeEffectSizesMatchTheApprovedMasks() {
    XCTAssertEqual(ReaderVisualTokens.topProgressiveBlurHeight, 148)
    XCTAssertEqual(ReaderVisualTokens.bottomSoftEdgeHeight, 98)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -derivedDataPath /private/tmp/deepreading-native-visual-derived -destination 'platform=iOS Simulator,id=26B9A0D8-2E67-40FF-886A-DAFA0E02E513' -only-testing:DeepReadingVisualPrototypeTests/ReaderPrototypeModelTests
```

Expected: compilation failure because the two visual-token names do not exist.

- [ ] **Step 3: Add the two visual tokens**

```swift
static let topProgressiveBlurHeight: CGFloat = 148
static let bottomSoftEdgeHeight: CGFloat = 98
```

- [ ] **Step 4: Run test to verify it passes**

Run the command from Step 2. Expected: all `ReaderPrototypeModelTests` pass.

### Task 2: Add the local variable-radius blur overlay

**Files:**
- Create: `ios_visual_prototype/DeepReadingVisualPrototype/ReaderProgressiveBlurView.swift`
- Modify: `ios_visual_prototype/DeepReadingVisualPrototype/ReaderPrototypeView.swift`

**Interfaces:**
- Consumes: `ReaderVisualTokens.topProgressiveBlurHeight`.
- Produces: `ReaderTopProgressiveBlur`, a non-interactive SwiftUI view with `isVisible: Bool`.
- Preserves: `ReaderTopGlassControls`, top 44pt controls at y=52, and bottom `.soft` scroll-edge effect.

- [ ] **Step 1: Write the failing test**

```swift
func testFocusedStateKeepsOnlyAIWhileReaderChromeAndTopEdgeAreHidden() {
    var state = ReaderPrototypeState.initial
    state.handleScroll(.down)

    XCTAssertFalse(state.readerChromeIsVisible)
    XCTAssertTrue(state.aiControlIsVisible)
}
```

- [ ] **Step 2: Run test to verify it passes before visual wiring**

Run the command from Task 1, Step 2. Expected: existing model rule still passes; it protects the visibility contract while the view hierarchy changes.

- [ ] **Step 3: Implement the local overlay**

Create a `UIViewRepresentable` that makes a `UIVisualEffectView`, installs the variable blur filter with a vertical mask whose alpha is strongest at the top, and suppresses the standard dimming subviews. Wrap it in `ReaderTopProgressiveBlur`, overlay it with a `ReaderVisualTokens.background` top-to-bottom opacity gradient, set its height to `topProgressiveBlurHeight`, ignore only the top safe area, disable hit testing, and animate its opacity from `isVisible`.

- [ ] **Step 4: Wire the overlay between the ScrollView and controls**

Place `ReaderTopProgressiveBlur(isVisible: state.readerChromeIsVisible)` above the scrolling article but below the existing safe-area control bars. Retain `.scrollEdgeEffectStyle(.soft, for: .bottom)`, hide the top system edge effect to prevent doubling, and retain the existing focused-state suppression for the bottom edge effect.

- [ ] **Step 5: Build and inspect the Simulator**

Run:

```bash
xcodebuild build -project ios_visual_prototype/DeepReadingVisualPrototype.xcodeproj -scheme DeepReadingVisualPrototype -derivedDataPath /private/tmp/deepreading-native-visual-derived -destination 'platform=iOS Simulator,id=26B9A0D8-2E67-40FF-886A-DAFA0E02E513'
```

Then install, launch, scroll the reader beneath the top overlay, and confirm: text becomes progressively more blurred toward the top, no hard clipping appears, and the overlay disappears when reader chrome is hidden.
