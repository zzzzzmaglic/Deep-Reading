import Foundation

struct SupabaseRuntimeConfiguration: Sendable, Equatable {
    let url: URL
    let anonKey: String

    static func load(bundle: Bundle = .main) throws -> SupabaseRuntimeConfiguration {
        let values = [
            "SUPABASE_URL": bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            "SUPABASE_ANON_KEY": bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
        ]
        return try load(values: values)
    }

    static func load(values: [String: String?]) throws -> SupabaseRuntimeConfiguration {
        let urlValue = try requiredValue(named: "SUPABASE_URL", in: values)
        let anonKey = try requiredValue(named: "SUPABASE_ANON_KEY", in: values)

        guard let url = URL(string: urlValue), let scheme = url.scheme, !scheme.isEmpty, url.host != nil else {
            throw SupabaseRuntimeConfigurationError.invalidURL
        }

        return SupabaseRuntimeConfiguration(url: url, anonKey: anonKey)
    }

    private static func requiredValue(
        named name: String,
        in values: [String: String?]
    ) throws -> String {
        guard let rawValue = values[name] ?? nil else {
            throw SupabaseRuntimeConfigurationError.missingValue(name)
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.contains("$(") else {
            throw SupabaseRuntimeConfigurationError.missingValue(name)
        }
        return value
    }
}

enum SupabaseRuntimeConfigurationError: Error, Equatable, LocalizedError {
    case missingValue(String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case let .missingValue(name):
            "Missing required public configuration: \(name)."
        case .invalidURL:
            "SUPABASE_URL must be a valid URL."
        }
    }
}
