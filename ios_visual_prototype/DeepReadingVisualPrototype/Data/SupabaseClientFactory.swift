import Foundation
import Supabase

enum SupabaseClientFactory {
    static func makeClient(configuration: SupabaseRuntimeConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: .init(auth: .init(storage: UserDefaultsAuthStorage()))
        )
    }
}

private final class UserDefaultsAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: key)
    }
}
