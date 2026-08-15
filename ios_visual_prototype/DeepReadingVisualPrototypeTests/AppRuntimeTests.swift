import SwiftUI
import Supabase
import UIKit
import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class AppRuntimeTests: XCTestCase {
    func testAppRootBootstrapsInjectedRuntimeAndRendersReadyState() async throws {
        let runtime = FakeRuntime()
        let recorder = AppRuntimeRenderRecorder()
        let controller = UIHostingController(rootView: AppRootView(configurationLoader: { try self.configuration() }, runtimeBuilder: { _ in runtime }, renderObserver: recorder.record))
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(75))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.layoutIfNeeded()
        XCTAssertEqual(runtime.bootstrapCalls, 1)
        XCTAssertTrue(recorder.elements.contains(.text("Reader runtime ready")))
    }

    func testAppRootRendersRetryWhenRuntimeBootstrapFails() async throws {
        let runtime = FakeRuntime(error: FakeRuntimeError.bootstrapFailed)
        let recorder = AppRuntimeRenderRecorder()
        let controller = UIHostingController(rootView: AppRootView(configurationLoader: { try self.configuration() }, runtimeBuilder: { _ in runtime }, renderObserver: recorder.record))
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(75))
        XCTAssertTrue(recorder.elements.contains(.text("无法连接阅读服务")))
        XCTAssertTrue(recorder.elements.contains(.button("重试")))
    }

    func testActualRuntimeKeepsOneClientForServicesAfterRootReachesReady() async throws {
        var client: SupabaseClient? = makeClient()
        weak var retainedClient = client
        var runtime: AppRuntime? = AppRuntime(client: try XCTUnwrap(client), sessionBootstrap: {})
        weak var retainedRuntime = runtime
        let recorder = AppRuntimeRenderRecorder()
        let controller = UIHostingController(rootView: AppRootView(
            configurationLoader: { try self.configuration() },
            runtimeBuilder: { _ in runtime! },
            renderObserver: recorder.record
        ))
        let window = try makeWindow(rootViewController: controller)
        defer { window.isHidden = true }

        XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(client)), try XCTUnwrap(runtime?.sessionStore.clientIdentity))
        XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(client)), try XCTUnwrap(runtime?.articleRepository.clientIdentity))
        XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(client)), try XCTUnwrap(runtime?.readingAssetRepository.clientIdentity))

        controller.loadViewIfNeeded()
        try await Task.sleep(for: .milliseconds(75))
        runtime = nil
        client = nil
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertTrue(recorder.elements.contains(.text("Reader runtime ready")))
        XCTAssertNotNil(retainedRuntime)
        XCTAssertNotNil(retainedClient)
    }

    private func configuration() throws -> SupabaseRuntimeConfiguration {
        try SupabaseRuntimeConfiguration.load(values: ["SUPABASE_URL": "http://127.0.0.1:54321", "SUPABASE_ANON_KEY": "test-key"])
    }

    private func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "test-key"
        )
    }

    private func makeWindow(rootViewController: UIViewController) throws -> UIWindow {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { throw XCTSkip("The test host does not provide a window scene.") }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        return window
    }
}

private enum FakeRuntimeError: Error { case bootstrapFailed }
private final class FakeRuntime: AppRuntimeBootstrapping, @unchecked Sendable {
    private let error: Error?
    private(set) var bootstrapCalls = 0
    init(error: Error? = nil) { self.error = error }
    func bootstrap() async throws { bootstrapCalls += 1; if let error { throw error } }
}
@MainActor private final class AppRuntimeRenderRecorder {
    private(set) var elements: [AppRootRenderedElement] = []
    func record(_ element: AppRootRenderedElement) { elements.append(element) }
}
