import 'package:app/core/network/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AnonymousAuthClient {
  Object? get currentSession;

  Future<void> signInAnonymously();
}

class AnonymousAuthService {
  const AnonymousAuthService(this._client);

  final AnonymousAuthClient _client;

  Future<void> ensureSession() async {
    if (_client.currentSession == null) {
      await _client.signInAnonymously();
    }
  }
}

class SupabaseAnonymousAuthClient implements AnonymousAuthClient {
  const SupabaseAnonymousAuthClient(this._client);

  final SupabaseClient _client;

  @override
  Object? get currentSession => _client.auth.currentSession;

  @override
  Future<void> signInAnonymously() async {
    await _client.auth.signInAnonymously();
  }
}

final anonymousAuthServiceProvider = Provider<AnonymousAuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AnonymousAuthService(SupabaseAnonymousAuthClient(client));
});

final anonymousAuthBootstrapProvider = FutureProvider<void>((ref) {
  return ref.watch(anonymousAuthServiceProvider).ensureSession();
});
