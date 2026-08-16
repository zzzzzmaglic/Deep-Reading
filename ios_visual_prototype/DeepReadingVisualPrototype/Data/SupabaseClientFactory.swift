import Supabase

enum SupabaseClientFactory {
    static func makeClient(configuration: SupabaseRuntimeConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey
        )
    }
}
