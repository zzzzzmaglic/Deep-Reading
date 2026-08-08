import 'package:app/app.dart';
import 'package:app/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reader route preserves an anchor in its route context', (
    tester,
  ) async {
    await tester.pumpWidget(
      DeepReadingApp.routerForTest('/reader/a-1', anchorId: 'anchor-1'),
    );

    expect(find.byKey(const Key('reader-anchor-anchor-1')), findsOneWidget);
  });

  test('reader route context records its origin and optional anchor', () {
    const context = ReaderRouteContext(
      origin: ReaderOrigin.knowledge,
      anchorId: 'anchor-1',
    );

    expect(context.origin, ReaderOrigin.knowledge);
    expect(context.anchorId, 'anchor-1');
  });
}
