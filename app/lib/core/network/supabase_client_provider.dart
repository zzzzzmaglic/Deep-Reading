import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> initializeSupabase() async {
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    if (kDebugMode) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be configured in debug mode.',
      );
    }
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
