# Deep Reading

The first core user-path Demo targets iOS only. Windows is used for source and
logic checks, not release acceptance.

## Local checks

```powershell
cd app
flutter pub get
flutter test
```

Run `flutter analyze` and `dart format --set-exit-if-changed .` before sending
changes for review.
