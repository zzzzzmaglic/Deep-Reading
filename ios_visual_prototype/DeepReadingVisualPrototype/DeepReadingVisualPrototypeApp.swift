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
    var knowledgeDependencies: KnowledgeDependencies? { get }
}

extension AppRuntimeBootstrapping {
    var readerDependencies: ReaderDependencies? { nil }
    var knowledgeDependencies: KnowledgeDependencies? { nil }
}

final class AppRuntime: AppRuntimeBootstrapping, @unchecked Sendable {
    let client: SupabaseClient
    let sessionStore: AppSessionStore
    let articleRepository: SupabaseArticleRepository
    let readingAssetRepository: SupabaseReadingAssetRepository
    let knowledgeRepository: SupabaseKnowledgeBaseRepository
    let readerDependencies: ReaderDependencies?
    let knowledgeDependencies: KnowledgeDependencies?
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
        knowledgeRepository = SupabaseKnowledgeBaseRepository(client: client)
        readerDependencies = ReaderDependencies(
            articleRepository: articleRepository,
            readingAssetRepository: readingAssetRepository
        )
        knowledgeDependencies = KnowledgeDependencies(
            knowledgeRepository: knowledgeRepository,
            readerDependencies: readerDependencies!
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

enum AppTab: String, CaseIterable, Hashable, Sendable, TabItem {
    case home = "首页"
    case knowledge = "知识库"

    static let defaultSelection = AppTab.knowledge

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .knowledge: return "books.vertical.fill"
        }
    }

    var actionSymbol: String {
        switch self {
        case .home: return "house"
        case .knowledge: return "books.vertical"
        }
    }
}

enum KnowledgeNavigationDestination: Hashable {
    case collection(id: UUID, title: String)
    case tag(id: UUID, title: String)
    case reader(ReaderRoute)
    case summary(articleID: UUID, origin: ReaderOrigin)
}

enum KnowledgeNavigationInitialPath {
    static let uiTestOpenLocalSeedReaderArgument = "-ui-test-open-local-seed-reader"

    static func destinations(arguments: [String]) -> [KnowledgeNavigationDestination] {
        #if DEBUG
        guard arguments.contains(uiTestOpenLocalSeedReaderArgument) else { return [] }
        return [.reader(ReaderRoute(articleID: ReaderRoute.localSeed.articleID, anchorID: nil, origin: .knowledge))]
        #else
        return []
        #endif
    }
}

enum KnowledgeAccessibilityIdentifier {
    static func collection(_ id: UUID) -> String { "knowledge-collection-\(id.uuidString)" }
    static func tag(_ id: UUID) -> String { "knowledge-tag-\(id.uuidString)" }
}

struct KnowledgeDependencies: @unchecked Sendable {
    let knowledgeRepository: any KnowledgeBaseRepository
    let readerDependencies: ReaderDependencies
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
    @State private var selectedTab = AppTab.defaultSelection
    @State private var hidesCustomTabBar = false
    @State private var tabBarBottomInset: CGFloat = 0

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
            #if DEBUG
            if let variant = TabBarABVariant.from(arguments: ProcessInfo.processInfo.arguments) {
                TabBarABExperimentRoot(variant: variant)
            } else {
                runtimeBody
            }
            #else
            runtimeBody
            #endif
        }
    }

    @ViewBuilder
    private var runtimeBody: some View {
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
                if let dependencies = runtime?.knowledgeDependencies {
                    TabView(selection: $selectedTab) {
                        HomeUnavailableScreen()
                            .tag(AppTab.home)
                            .toolbarVisibility(.hidden, for: .tabBar)
                        KnowledgeNavigationContainer(
                            dependencies: dependencies,
                            hidesCustomTabBar: $hidesCustomTabBar
                        )
                        .tag(AppTab.knowledge)
                        .toolbarVisibility(.hidden, for: .tabBar)
                    }
                    .safeAreaBar(edge: .bottom, spacing: 0) {
                        if selectedTab == .home || !hidesCustomTabBar {
                            KnowledgeGlassTabBar(selection: $selectedTab)
                                .ignoresSafeArea()
                                .padding(.leading, KnowledgeVisualTokens.tabBarLeadingInset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(
                                    .bottom,
                                    -tabBarBottomInset + KnowledgeVisualTokens.tabBarBottomInset
                                )
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.safeAreaInsets.bottom
                                } action: { value in
                                    tabBarBottomInset = value
                                }
                        }
                    }
                    .onAppear { renderObserver?(.text("Knowledge runtime ready")) }
                } else {
                    Text("Knowledge runtime ready")
                        .accessibilityIdentifier("app-root-runtime-ready")
                        .onAppear { renderObserver?(.text("Knowledge runtime ready")) }
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

private struct HomeUnavailableScreen: View {
    var body: some View {
        ZStack {
            KnowledgeVisualTokens.background
                .ignoresSafeArea()

            ContentUnavailableView("阅读流尚未实现", systemImage: "house")
                .accessibilityIdentifier("knowledge-home-placeholder")
        }
    }
}

private struct KnowledgeNavigationContainer: View {
    let dependencies: KnowledgeDependencies
    @Binding var hidesCustomTabBar: Bool
    @State private var path: [KnowledgeNavigationDestination]
    @State private var readerAssetRefreshRevision = 0
    @State private var detailSelectionIsActive = false

    init(dependencies: KnowledgeDependencies) {
        self._hidesCustomTabBar = .constant(false)
        self.dependencies = dependencies
        _path = State(initialValue: KnowledgeNavigationInitialPath.destinations(arguments: ProcessInfo.processInfo.arguments))
    }

    init(dependencies: KnowledgeDependencies, hidesCustomTabBar: Binding<Bool>) {
        self._hidesCustomTabBar = hidesCustomTabBar
        self.dependencies = dependencies
        _path = State(initialValue: KnowledgeNavigationInitialPath.destinations(arguments: ProcessInfo.processInfo.arguments))
    }

    var body: some View {
        NavigationStack(path: $path) {
            KnowledgeHomeScreen(repository: dependencies.knowledgeRepository)
            .navigationDestination(for: KnowledgeNavigationDestination.self) { destination in
                switch destination {
                case let .collection(id, title):
                    CollectionDetailScreen(
                        collectionID: id,
                        initialTitle: title,
                        repository: dependencies.knowledgeRepository,
                        selectionStateChanged: { detailSelectionIsActive = $0 },
                        openArticle: { article in
                            path.append(.reader(ReaderRoute(articleID: article.id, anchorID: nil, origin: .knowledge)))
                        }
                    )
                case let .tag(id, title):
                    TagDetailScreen(
                        tagID: id,
                        initialTitle: title,
                        dependencies: dependencies.readerDependencies,
                        selectionStateChanged: { detailSelectionIsActive = $0 },
                        showInArticle: { path.append(.reader($0)) }
                    )
                case let .reader(route):
                    ReaderScreen(
                        route: route,
                        dependencies: dependencies.readerDependencies,
                        onOpenSummary: { route in
                            path.append(.summary(articleID: route.articleID, origin: route.origin))
                        },
                        assetRefreshRevision: readerAssetRefreshRevision
                    )
                    .toolbar(.hidden, for: .tabBar)
                case let .summary(articleID, origin):
                    ArticleAssetSummaryScreen(
                        articleID: articleID,
                        origin: origin,
                        dependencies: dependencies.readerDependencies,
                        showInArticle: replaceReaderAfterDismissingSummary,
                        refreshReaderAssets: { readerAssetRefreshRevision += 1 }
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
            }
            .onAppear(perform: updateCustomTabBarVisibility)
            .onChange(of: path) { _, _ in updateCustomTabBarVisibility() }
            .onChange(of: detailSelectionIsActive) { _, _ in updateCustomTabBarVisibility() }
        }
    }

    private func updateCustomTabBarVisibility() {
        hidesCustomTabBar = detailSelectionIsActive || path.contains { destination in
            switch destination {
            case .reader, .summary:
                true
            case .collection, .tag:
                false
            }
        }
    }

    private func replaceReaderAfterDismissingSummary(with route: ReaderRoute) {
        guard case .summary = path.last else { return }
        path.removeLast()
        guard !path.isEmpty else { return }
        path[path.count - 1] = .reader(route)
    }
}

private struct KnowledgeGlassTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        UIKitKnowledgeGlassTabBar(
            selection: $selection,
            accessibilityIdentifier: "knowledge-glass-tab-bar"
        )
        .frame(width: KnowledgeVisualTokens.tabBarWidth, height: KnowledgeVisualTokens.tabBarHeight)
    }
}
