import Foundation
import Supabase

enum SupabaseClientFactory {
    static func makeClient(configuration: SupabaseRuntimeConfiguration) -> SupabaseClient {
        // Appetize runs an unsigned Release simulator build. Its Keychain has no
        // application entitlement (-34018), so keep each trial's Auth session in
        // memory. Signed local Debug builds and physical devices retain Keychain.
        #if targetEnvironment(simulator) && !DEBUG
        let options = SupabaseClientOptions(auth: .init(storage: DemoSessionMemoryStorage()))
        #else
        let options = SupabaseClientOptions()
        #endif
        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: options
        )
    }
}

final class DemoSessionMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
}
