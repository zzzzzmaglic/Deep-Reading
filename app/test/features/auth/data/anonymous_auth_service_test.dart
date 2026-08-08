import 'package:app/app.dart';
import 'package:app/features/auth/data/anonymous_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anonymous bootstrap does not replace an existing session', () async {
    final client = FakeSupabaseClient.withSession();

    await AnonymousAuthService(client).ensureSession();

    expect(client.anonymousSignInCalls, 0);
  });

  test('anonymous bootstrap signs in when no session exists', () async {
    final client = FakeSupabaseClient.withoutSession();

    await AnonymousAuthService(client).ensureSession();

    expect(client.anonymousSignInCalls, 1);
  });

  testWidgets('app startup executes the anonymous bootstrap provider', (
    tester,
  ) async {
    final client = FakeSupabaseClient.withoutSession();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anonymousAuthServiceProvider.overrideWithValue(
            AnonymousAuthService(client),
          ),
        ],
        child: const DeepReadingApp(),
      ),
    );

    await tester.pump();

    expect(client.anonymousSignInCalls, 1);
  });

  testWidgets('app startup preserves an existing session', (tester) async {
    final client = FakeSupabaseClient.withSession();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anonymousAuthServiceProvider.overrideWithValue(
            AnonymousAuthService(client),
          ),
        ],
        child: const DeepReadingApp(),
      ),
    );

    await tester.pump();

    expect(client.anonymousSignInCalls, 0);
  });
}

class FakeSupabaseClient implements AnonymousAuthClient {
  FakeSupabaseClient.withSession() : _session = const Object();

  FakeSupabaseClient.withoutSession();

  Object? _session;
  int anonymousSignInCalls = 0;

  @override
  Object? get currentSession => _session;

  @override
  Future<void> signInAnonymously() async {
    anonymousSignInCalls++;
    _session = const Object();
  }
}
