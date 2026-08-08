import 'package:app/app.dart';
import 'package:app/features/auth/data/anonymous_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots the Deep Reading application', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anonymousAuthBootstrapProvider.overrideWith((ref) async {}),
        ],
        child: const DeepReadingApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Deep Reading'), findsOneWidget);
  });
}
