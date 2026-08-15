import Foundation

struct SupabaseRuntimeConfiguration: Sendable, Equatable {
    let url: URL
    let anonKey: String

    static func load(bundle: Bundle = .main) throws -> SupabaseRuntimeConfiguration {
        let bundleValues = [
            "SUPABASE_URL": bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            "SUPABASE_ANON_KEY": bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
        ]
        return try load(
            environment: ProcessInfo.processInfo.environment,
            bundleValues: bundleValues
        )
    }

    static func load(values: [String: String?]) throws -> SupabaseRuntimeConfiguration {
        try load(environment: [:], bundleValues: values)
    }

    static func load(
        environment: [String: String],
        bundleValues: [String: String?]
    ) throws -> SupabaseRuntimeConfiguration {
        let urlValue = try requiredValue(
            named: "SUPABASE_URL",
            environment: environment,
            bundleValues: bundleValues
        )
        let anonKey = try requiredValue(
            named: "SUPABASE_ANON_KEY",
            environment: environment,
            bundleValues: bundleValues
        )

        guard let url = URL(string: urlValue), let scheme = url.scheme, !scheme.isEmpty, url.host != nil else {
            throw SupabaseRuntimeConfigurationError.invalidURL
        }

        return SupabaseRuntimeConfiguration(url: url, anonKey: anonKey)
    }

    private static func requiredValue(
        named name: String,
        environment: [String: String],
        bundleValues: [String: String?]
    ) throws -> String {
        let rawValue = environment[name] ?? (bundleValues[name] ?? nil)
        guard let rawValue else {
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
