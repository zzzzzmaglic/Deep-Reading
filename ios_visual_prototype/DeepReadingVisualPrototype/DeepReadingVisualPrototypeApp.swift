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

struct AppRootView: View {
    @State private var configurationError: SupabaseRuntimeConfigurationError?

    var body: some View {
        Group {
            if let configurationError {
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
            } else {
                ProgressView("正在准备阅读服务…")
            }
        }
        .task { loadConfiguration() }
    }

    private func loadConfiguration() {
        do {
            _ = try SupabaseRuntimeConfiguration.load()
            configurationError = nil
        } catch let error as SupabaseRuntimeConfigurationError {
            configurationError = error
        } catch {
            configurationError = .missingValue("SUPABASE_URL")
        }
    }
}
