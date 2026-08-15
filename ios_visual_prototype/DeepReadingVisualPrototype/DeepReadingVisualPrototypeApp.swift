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

    var showsRetry: Bool {
        if case .configurationFailure = self {
            return true
        }
        return false
    }

    var displaysFixtureArticle: Bool { false }
}

struct AppRootView: View {
    @State private var screen = AppRootScreen.loading

    var body: some View {
        Group {
            switch screen {
            case let .configurationFailure(configurationError):
                VStack(spacing: 16) {
                    Text("无法启动阅读服务")
                        .font(.title2.weight(.semibold))
                    Text(configurationError.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("重试", action: loadConfiguration)
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
            case .loading, .configured:
                ProgressView("正在准备阅读服务…")
            }
        }
        .task { loadConfiguration() }
    }

    private func loadConfiguration() {
        do {
            _ = try SupabaseRuntimeConfiguration.load()
            screen = .configured
        } catch let error as SupabaseRuntimeConfigurationError {
            screen = .configurationFailure(error)
        } catch {
            screen = .configurationFailure(.missingValue("SUPABASE_URL"))
        }
    }
}
