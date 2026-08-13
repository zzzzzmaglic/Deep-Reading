import 'package:app/app.dart';
import 'package:app/features/auth/data/anonymous_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('boots the Debug QA launch screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anonymousAuthBootstrapProvider.overrideWith((ref) async {}),
        ],
        child: const DeepReadingApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Deep Reading QA'), findsOneWidget);
    expect(find.byKey(const Key('debug-qa-open-reader')), findsOneWidget);
  });
}
