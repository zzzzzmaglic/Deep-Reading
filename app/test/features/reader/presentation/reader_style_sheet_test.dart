import 'package:app/features/reader/presentation/reader_style_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('font controls stop at the configured boundary', (tester) async {
    await pumpStyleSheet(tester, fontIndex: 4);

    expect(
      tester.widget<IconButton>(find.byKey(const Key('increase-font'))).onPressed,
      isNull,
    );
  });
}

Future<void> pumpStyleSheet(WidgetTester tester, {required int fontIndex}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReaderStyleSheet(fontIndex: fontIndex),
      ),
    ),
  );
}
