import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots the Deep Reading application', (tester) async {
    await tester.pumpWidget(const DeepReadingApp());

    expect(find.text('Deep Reading'), findsOneWidget);
  });
}
