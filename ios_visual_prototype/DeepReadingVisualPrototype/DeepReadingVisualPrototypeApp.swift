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

enum AppTab: Hashable {
    case home
    case knowledge

    static let defaultSelection = AppTab.knowledge
}

enum KnowledgeNavigationDestination: Hashable {
    case collection(UUID)
    case tag(UUID)
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
                if let dependencies = runtime?.knowledgeDependencies {
                    ZStack(alignment: .bottomLeading) {
                        HomeUnavailableScreen()
                            .opacity(selectedTab == .home ? 1 : 0)
                            .allowsHitTesting(selectedTab == .home)
                        KnowledgeNavigationContainer(
                            dependencies: dependencies,
                            hidesCustomTabBar: $hidesCustomTabBar
                        )
                        .opacity(selectedTab == .knowledge ? 1 : 0)
                        .allowsHitTesting(selectedTab == .knowledge)

                        if selectedTab == .home || !hidesCustomTabBar {
                            KnowledgeGlassTabBar(selection: $selectedTab)
                                .padding(.leading, KnowledgeVisualTokens.tabBarLeadingInset)
                                .padding(.bottom, KnowledgeVisualTokens.tabBarBottomInset)
                        }
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                    .onAppear { renderObserver?(.text("Knowledge runtime ready")) }
                } else {
                    Text("Knowledge runtime ready")
                        .accessibilityIdentifier("app-root-runtime-ready")
                        .onAppear { renderObserver?(.text("Knowledge runtime ready")) }
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

private struct HomeUnavailableScreen: View {
    var body: some View {
        ContentUnavailableView("阅读流尚未实现", systemImage: "house")
            .accessibilityIdentifier("knowledge-home-placeholder")
    }
}

private struct KnowledgeNavigationContainer: View {
    let dependencies: KnowledgeDependencies
    @Binding var hidesCustomTabBar: Bool
    @State private var path: [KnowledgeNavigationDestination]
    @State private var readerAssetRefreshRevision = 0

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
                case let .collection(id):
                    CollectionDetailScreen(
                        collectionID: id,
                        repository: dependencies.knowledgeRepository,
                        dismiss: popCurrentDestination,
                        openArticle: { article in
                            path.append(.reader(ReaderRoute(articleID: article.id, anchorID: nil, origin: .knowledge)))
                        }
                    )
                case let .tag(id):
                    TagDetailScreen(
                        tagID: id,
                        dependencies: dependencies.readerDependencies,
                        dismiss: popCurrentDestination,
                        showInArticle: { path.append(.reader($0)) }
                    )
                case let .reader(route):
                    ReaderScreen(
                        route: route,
                        dependencies: dependencies.readerDependencies,
                        onOpenSummary: { route in
                            path.append(.summary(articleID: route.articleID, origin: route.origin))
                        },
                        onBack: { _ in popCurrentDestination() },
                        assetRefreshRevision: readerAssetRefreshRevision
                    )
                    .toolbar(.hidden, for: .tabBar)
                case let .summary(articleID, origin):
                    ArticleAssetSummaryScreen(
                        articleID: articleID,
                        origin: origin,
                        dependencies: dependencies.readerDependencies,
                        dismissToReader: popCurrentDestination,
                        showInArticle: replaceReaderAfterDismissingSummary,
                        refreshReaderAssets: { readerAssetRefreshRevision += 1 }
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
            }
            .onAppear(perform: updateCustomTabBarVisibility)
            .onChange(of: path) { _, _ in updateCustomTabBarVisibility() }
        }
    }

    private func updateCustomTabBarVisibility() {
        hidesCustomTabBar = path.contains { destination in
            switch destination {
            case .reader, .summary:
                true
            case .collection, .tag:
                false
            }
        }
    }

    private func popCurrentDestination() {
        guard !path.isEmpty else { return }
        path.removeLast()
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
    @State private var visualSelection: AppTab
    @State private var selectionCommitTask: Task<Void, Never>?

    init(selection: Binding<AppTab>) {
        _selection = selection
        _visualSelection = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack(alignment: .leading) {
                selectionPill
                HStack(spacing: 0) {
                    tabButton(tab: .home, title: "首页", image: "KnowledgeTabHome")
                    tabButton(tab: .knowledge, title: "知识库", image: "KnowledgeTabLibrary")
                }
            }
            .padding(.horizontal, 2)
            .frame(width: KnowledgeVisualTokens.tabBarWidth, height: KnowledgeVisualTokens.tabBarHeight)
            // Keep exactly one native Liquid Glass surface. `.interactive()`
            // adds a press-time material resample, which was visible as a
            // dark-pill flash when the selected page changed beneath the bar.
            .glassEffect(.regular, in: Capsule())
        }
        .accessibilityIdentifier("knowledge-glass-tab-bar")
        .onChange(of: selection) { _, newSelection in
            guard newSelection != visualSelection else { return }
            selectionCommitTask?.cancel()
            withAnimation(.smooth(duration: 0.24, extraBounce: 0)) {
                visualSelection = newSelection
            }
        }
        .onDisappear {
            selectionCommitTask?.cancel()
        }
    }

    /// The moving selected state is intentionally a stable fill rather than a
    /// second glass surface. iOS Liquid Glass cannot sample another glass
    /// element without forcing a second compositing pass while it moves.
    private var selectionPill: some View {
        Capsule()
            .fill(KnowledgeTabBarPolicy.selectedPillFill)
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 1, y: 1)
            .frame(width: KnowledgeVisualTokens.tabBarItemWidth, height: 54)
            .offset(x: visualSelection == .home ? 0 : KnowledgeVisualTokens.tabBarItemWidth + KnowledgeVisualTokens.knowledgeTabSelectedBackgroundOffset)
            .allowsHitTesting(false)
            .animation(.smooth(duration: 0.24, extraBounce: 0), value: visualSelection)
    }

    private func tabButton(tab: AppTab, title: String, image: String) -> some View {
        Button {
            select(tab)
        } label: {
            VStack(spacing: 1) {
                Image(image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: KnowledgeVisualTokens.tabBarIconSize, height: KnowledgeVisualTokens.tabBarIconSize)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(-0.1)
            }
            .foregroundStyle(visualSelection == tab ? KnowledgeTabBarPolicy.selectedContentTint : Color(hex: 0x1A1A1A))
            .offset(x: tab == .knowledge ? KnowledgeVisualTokens.knowledgeTabSelectedContentOffset : 0)
            .frame(width: KnowledgeVisualTokens.tabBarItemWidth, height: 54)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("knowledge-tab-\(title)")
        .accessibilityLabel(title)
    }

    private func select(_ tab: AppTab) {
        guard tab != visualSelection else { return }

        selectionCommitTask?.cancel()
        withAnimation(.smooth(duration: 0.24, extraBounce: 0)) {
            visualSelection = tab
        }
        selectionCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: KnowledgeTabBarPolicy.selectionCommitDelayMilliseconds * 1_000_000)
            guard !Task.isCancelled, visualSelection == tab else { return }
            selection = tab
        }
    }
}
