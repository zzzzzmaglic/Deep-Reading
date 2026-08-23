import SwiftUI
import Supabase
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
    case ready
    case configurationFailure(SupabaseRuntimeConfigurationError)
    case sessionFailure

    var showsRetry: Bool {
        switch self {
        case .configurationFailure, .sessionFailure:
            return true
        case .loading, .configured, .ready:
            return false
        }
    }

    var displaysFixtureArticle: Bool { false }
}

protocol AppRuntimeBootstrapping: AnyObject {
    func bootstrap() async throws
    var readerDependencies: ReaderDependencies? { get }
}

extension AppRuntimeBootstrapping {
    var readerDependencies: ReaderDependencies? { nil }
}

final class AppRuntime: AppRuntimeBootstrapping, @unchecked Sendable {
    let client: SupabaseClient
    let sessionStore: AppSessionStore
    let articleRepository: SupabaseArticleRepository
    let readingAssetRepository: SupabaseReadingAssetRepository
    let readerDependencies: ReaderDependencies?
    private let sessionBootstrap: @Sendable () async throws -> Void

    convenience init(configuration: SupabaseRuntimeConfiguration) {
        self.init(client: SupabaseClientFactory.makeClient(configuration: configuration))
    }

    init(
        client: SupabaseClient,
        sessionBootstrap: (@Sendable () async throws -> Void)? = nil
    ) {
        self.client = client
        let sessionStore = AppSessionStore(client: client)
        self.sessionStore = sessionStore
        articleRepository = SupabaseArticleRepository(client: client)
        readingAssetRepository = SupabaseReadingAssetRepository(client: client)
        readerDependencies = ReaderDependencies(
            articleRepository: articleRepository,
            readingAssetRepository: readingAssetRepository
        )
        self.sessionBootstrap = sessionBootstrap ?? { [sessionStore] in
            try await sessionStore.bootstrap()
        }
    }

    func bootstrap() async throws {
        try await sessionBootstrap()
    }
}

enum AppRootRenderedElement: Equatable {
    case text(String)
    case button(String)
}

enum AppNavigationDestination: Hashable {
    case summary(articleID: UUID, origin: ReaderOrigin)
}

/// The reading flow is intentionally outside Stage F. AppRoot still owns the
/// semantic handoff so a replacement reader can exit to its original route
/// without ever rebuilding the summary path.
struct ReaderOriginDismissal {
    let dismiss: (ReaderOrigin) -> Void

    static let noOp = ReaderOriginDismissal(dismiss: { _ in })
}

struct AppRootView: View {
    private let configurationLoader: () throws -> SupabaseRuntimeConfiguration
    private let runtimeBuilder: (SupabaseRuntimeConfiguration) -> any AppRuntimeBootstrapping
    private let renderObserver: ((AppRootRenderedElement) -> Void)?
    private let originDismissal: ReaderOriginDismissal
    @State private var screen = AppRootScreen.loading
    @State private var runtime: (any AppRuntimeBootstrapping)?
    @State private var readerRoute = ReaderRoute.localSeed
    @State private var navigationPath: [AppNavigationDestination] = []
    @State private var readerAssetRefreshRevision = 0

    init(
        configurationLoader: @escaping () throws -> SupabaseRuntimeConfiguration = {
            try SupabaseRuntimeConfiguration.load()
        },
        runtimeBuilder: @escaping (SupabaseRuntimeConfiguration) -> any AppRuntimeBootstrapping = { AppRuntime(configuration: $0) },
        renderObserver: ((AppRootRenderedElement) -> Void)? = nil,
        originDismissal: ReaderOriginDismissal = .noOp
    ) {
        self.configurationLoader = configurationLoader
        self.runtimeBuilder = runtimeBuilder
        self.renderObserver = renderObserver
        self.originDismissal = originDismissal
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
                        .onAppear { renderObserver?(.text("无法连接阅读服务")) }
                    Button("重试", action: loadConfiguration)
                        .buttonStyle(.borderedProminent)
                        .onAppear { renderObserver?(.button("重试")) }
                }
                .padding(24)
            case .loading:
                ProgressView("正在准备阅读服务…")
            case .configured:
                ProgressView("正在准备阅读服务…")
                    .task { await bootstrapRuntime() }
            case .ready:
                if let dependencies = runtime?.readerDependencies {
                    NavigationStack(path: $navigationPath) {
                        ReaderScreen(
                            route: readerRoute,
                            dependencies: dependencies,
                            onOpenSummary: { route in
                                navigationPath.append(.summary(articleID: route.articleID, origin: route.origin))
                            },
                            onBack: originDismissal.dismiss,
                            assetRefreshRevision: readerAssetRefreshRevision
                        )
                        .navigationDestination(for: AppNavigationDestination.self) { destination in
                            switch destination {
                            case let .summary(articleID, origin):
                                ArticleAssetSummaryScreen(
                                    articleID: articleID,
                                    origin: origin,
                                    dependencies: dependencies,
                                    dismissToReader: { navigationPath.removeAll() },
                                    showInArticle: { anchoredRoute in
                                        navigationPath.removeAll()
                                        readerRoute = anchoredRoute
                                    },
                                    refreshReaderAssets: { readerAssetRefreshRevision += 1 }
                                )
                            }
                        }
                    }
                    .onAppear { renderObserver?(.text("Reader runtime ready")) }
                } else {
                    Text("Reader runtime ready")
                        .accessibilityIdentifier("app-root-runtime-ready")
                        .onAppear { renderObserver?(.text("Reader runtime ready")) }
                }
            }
        }
    }

    private func loadConfiguration() {
        runtime = nil
        screen = Self.loadScreen(using: configurationLoader)
    }

    private func bootstrapRuntime() async {
        do {
            let configuration = try configurationLoader()
            let newRuntime = runtimeBuilder(configuration)
            try await newRuntime.bootstrap()
            runtime = newRuntime
            screen = .ready
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
