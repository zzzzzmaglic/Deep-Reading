import Foundation
import Supabase

enum SupabaseClientFactory {
    static func makeClient(configuration: SupabaseRuntimeConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: .init(auth: .init(storage: KeychainBackedAuthStorage()))
        )
    }
}

private final class KeychainBackedAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let keychain = KeychainLocalStorage()
    private let lock = NSLock()
    private var volatileValues: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        defer { setVolatileValue(value, for: key) }
        try keychain.store(key: key, value: value)
    }

    func retrieve(key: String) throws -> Data? {
        if let storedValue = try? keychain.retrieve(key: key) {
            setVolatileValue(storedValue, for: key)
            return storedValue
        }
        return volatileValue(for: key)
    }

    func remove(key: String) throws {
        defer { setVolatileValue(nil, for: key) }
        try keychain.remove(key: key)
    }

    private func volatileValue(for key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return volatileValues[key]
    }

    private func setVolatileValue(_ value: Data?, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        volatileValues[key] = value
    }
}
