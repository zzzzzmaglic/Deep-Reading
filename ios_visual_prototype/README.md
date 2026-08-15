# Deep Reading Native Visual Prototype

This directory is an iOS 26 SwiftUI visual-validation prototype. It is independent of the Flutter app and uses only local static article data.

## Scope

- Figma reader Frames 01–08 only.
- Native iOS 26 Liquid Glass controls.
- No Supabase, DeepSeek, Appetize, product routing, or release workflow.

## Run

```bash
xcodebuild -project DeepReadingVisualPrototype.xcodeproj \
  -scheme DeepReadingVisualPrototype \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=Deep Reading · iPhone 16' build
```

Open or boot the iPhone 16 Simulator before launching the built app.
