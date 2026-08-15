import SwiftUI
import UIKit

@main
final class PrototypeAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = PrototypeSceneDelegate.self
        return configuration
    }
}

final class PrototypeSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: AppRootView())
        self.window = window
        window.makeKeyAndVisible()
    }
}

enum AppRootScreen: Equatable {
    case loading
    case configured
    case configurationFailure(SupabaseRuntimeConfigurationError)
    case sessionFailure

    var showsRetry: Bool {
        switch self {
        case .configurationFailure, .sessionFailure:
            return true
        case .loading, .configured:
            return false
        }
    }

    var displaysFixtureArticle: Bool { false }
}

enum AppRootRenderedElement: Equatable {
    case text(String)
    case button(String)
}

struct AppRootView: View {
    private let configurationLoader: () throws -> SupabaseRuntimeConfiguration
    private let sessionBootstrapper: () async throws -> Void
    private let renderObserver: ((AppRootRenderedElement) -> Void)?
    @State private var screen = AppRootScreen.loading

    init(
        configurationLoader: @escaping () throws -> SupabaseRuntimeConfiguration = {
            try SupabaseRuntimeConfiguration.load()
        },
        sessionBootstrapper: @escaping () async throws -> Void = {
            let configuration = try SupabaseRuntimeConfiguration.load()
            let client = SupabaseClientFactory.makeClient(configuration: configuration)
            try await AppSessionStore(client: client).bootstrap()
        },
        renderObserver: ((AppRootRenderedElement) -> Void)? = nil
    ) {
        self.configurationLoader = configurationLoader
        self.sessionBootstrapper = sessionBootstrapper
        self.renderObserver = renderObserver
        _screen = State(initialValue: Self.loadScreen(using: configurationLoader))
    }

    var body: some View {
        Group {
            switch screen {
            case let .configurationFailure(configurationError):
                VStack(spacing: 16) {
                    Text("无法启动阅读服务")
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("app-root-configuration-error-title")
                        .accessibilityLabel("无法启动阅读服务")
                        .onAppear { renderObserver?(.text("无法启动阅读服务")) }
                    Text(configurationError.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("app-root-configuration-error-message")
                        .accessibilityLabel(configurationError.localizedDescription)
                        .onAppear { renderObserver?(.text(configurationError.localizedDescription)) }
                    Button("重试", action: loadConfiguration)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("app-root-configuration-retry")
                        .accessibilityLabel("重试")
                        .onAppear { renderObserver?(.button("重试")) }
                }
                .padding(24)
                .accessibilityIdentifier("app-root-configuration-error")
            case .sessionFailure:
                VStack(spacing: 16) {
                    Text("无法连接阅读服务")
                        .font(.title2.weight(.semibold))
                    Button("重试", action: loadConfiguration)
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
            case .loading:
                ProgressView("正在准备阅读服务…")
            case .configured:
                ProgressView("正在准备阅读服务…")
                    .task { await bootstrapSession() }
            }
        }
    }

    private func loadConfiguration() {
        screen = Self.loadScreen(using: configurationLoader)
    }

    private func bootstrapSession() async {
        do {
            try await sessionBootstrapper()
        } catch {
            screen = .sessionFailure
        }
    }

    private static func loadScreen(
        using configurationLoader: () throws -> SupabaseRuntimeConfiguration
    ) -> AppRootScreen {
        do {
            _ = try configurationLoader()
            return .configured
        } catch let error as SupabaseRuntimeConfigurationError {
            return .configurationFailure(error)
        } catch {
            return .configurationFailure(.missingValue("SUPABASE_URL"))
        }
    }
}
