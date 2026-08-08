import 'package:app/features/reader/presentation/reader_style_sheet.dart';
import 'package:app/core/storage/preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  testWidgets('font controls stop at the configured boundary', (tester) async {
    await pumpStyleSheet(tester, fontIndex: 4);

    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('increase-font')))
          .onPressed,
      isNull,
    );
  });

  test(
    'preference store persists a supported font size and theme immediately',
    () async {
      final store = PreferenceStore(preferences: SharedPreferencesAsync());

      await store.saveReaderFontSize(23);
      await store.saveReaderTheme(ReaderThemeMode.dark.name);

      expect(await store.readReaderFontSize(), 23);
      expect(await store.readReaderTheme(), 'dark');
    },
  );
}

Future<void> pumpStyleSheet(WidgetTester tester, {required int fontIndex}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ReaderStyleSheet(fontIndex: fontIndex)),
    ),
  );
}
