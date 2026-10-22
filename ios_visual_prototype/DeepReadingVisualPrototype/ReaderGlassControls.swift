import SwiftUI
import UIKit

struct ReaderTopGlassControls: View {
    let onBack: () -> Void
    let onOpenSummary: () -> Void
    let isSummaryEnabled: Bool

    init(
        onBack: @escaping () -> Void = {},
        onOpenSummary: @escaping () -> Void = {},
        isSummaryEnabled: Bool = true
    ) {
        self.onBack = onBack
        self.onOpenSummary = onOpenSummary
        self.isSummaryEnabled = isSummaryEnabled
    }

    var body: some View {
        HStack {
            GlassIconControl(symbol: "chevron.left", label: "返回", action: onBack)
                .accessibilityIdentifier("reader-back")
            Spacer()
            GlassIconControl(
                symbol: "doc.text.magnifyingglass",
                label: "标注与笔记",
                action: onOpenSummary,
                isEnabled: isSummaryEnabled
            )
                .accessibilityIdentifier("reader-open-summary")
        }
        .padding(.horizontal, 20)
        .padding(.top, 52)
        .padding(.bottom, 8)
    }
}

struct ReaderBottomGlassControls: View {
    let showsReaderChrome: Bool
    let showsAIControl: Bool
    let showAssetCard: () -> Void

    var body: some View {
        HStack {
            if showsReaderChrome {
                GlassEffectContainer(spacing: 16) {
                    HStack(spacing: 10) {
                        Text("Aa")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("阅读器样式设置")
                            .accessibilityAddTraits(.isStaticText)
                            .allowsHitTesting(false)

                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 1, height: 20)

                        Button(action: showAssetCard) {
                            Image("FigmaToolIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .frame(width: 44, height: 44)
                        }
                        .contentShape(Rectangle())
                        .buttonStyle(ReaderBounceButtonStyle())
                        .accessibilityLabel("独立笔记")
                    }
                    .frame(width: 119, height: 44)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
            }

            Spacer()

            if showsAIControl {
                GlassIconControl(symbol: "circle.grid.2x2.fill", label: "AI 伴读（仅视觉）", action: {}, isEnabled: false)
            }
        }
        .padding(.horizontal, 22)
        // Bottom controls keep their 44pt height and 8pt top inset while the
        // 20pt lower inset places them closer to the screen edge.
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

/// Connects the custom SwiftUI control cluster to UIKit's native bottom scroll
/// edge. `UIScrollEdgeElementContainerInteraction` lets the system derive the
/// soft edge shape from the real glass controls instead of treating the
/// bottom of the `UITextView` as an unadorned viewport edge.
struct ReaderBottomScrollEdgeContainer: UIViewControllerRepresentable {
    let showsReaderChrome: Bool
    let showsAIControl: Bool
    let showAssetCard: () -> Void

    func makeUIViewController(context: Context) -> ReaderBottomScrollEdgeHostController {
        ReaderBottomScrollEdgeHostController(
            showsReaderChrome: showsReaderChrome,
            showsAIControl: showsAIControl,
            showAssetCard: showAssetCard
        )
    }

    func updateUIViewController(_ controller: ReaderBottomScrollEdgeHostController, context: Context) {
        controller.update(
            showsReaderChrome: showsReaderChrome,
            showsAIControl: showsAIControl,
            showAssetCard: showAssetCard
        )
    }
}

final class ReaderBottomScrollEdgeHostController: UIViewController {
    private let edgeInteraction = UIScrollEdgeElementContainerInteraction()
    private let controlsHost: UIHostingController<AnyView>

    init(
        showsReaderChrome: Bool,
        showsAIControl: Bool,
        showAssetCard: @escaping () -> Void
    ) {
        controlsHost = UIHostingController(
            rootView: AnyView(
                ReaderBottomGlassControls(
                    showsReaderChrome: showsReaderChrome,
                    showsAIControl: showsAIControl,
                    showAssetCard: showAssetCard
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
            )
        )
        // The representable already occupies the reader's physical bottom
        // edge. Do not let UIHostingController add the device safe area again;
        // ReaderBottomGlassControls' 20pt inset is the final screen distance.
        controlsHost.safeAreaRegions = []
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false

        addChild(controlsHost)
        controlsHost.view.backgroundColor = .clear
        controlsHost.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsHost.view)
        NSLayoutConstraint.activate([
            controlsHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsHost.view.topAnchor.constraint(equalTo: view.topAnchor),
            controlsHost.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controlsHost.didMove(toParent: self)

        edgeInteraction.edge = .bottom
        view.addInteraction(edgeInteraction)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        registerReaderScrollViewIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        registerReaderScrollViewIfNeeded()
    }

    func update(
        showsReaderChrome: Bool,
        showsAIControl: Bool,
        showAssetCard: @escaping () -> Void
    ) {
        controlsHost.rootView = AnyView(
            ReaderBottomGlassControls(
                showsReaderChrome: showsReaderChrome,
                showsAIControl: showsAIControl,
                showAssetCard: showAssetCard
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
        )
        registerReaderScrollViewIfNeeded()
    }

    private func registerReaderScrollViewIfNeeded() {
        guard let window = view.window,
              let textView = findReaderTextView(in: window) else { return }
        if edgeInteraction.scrollView !== textView {
            edgeInteraction.scrollView = textView
        }
    }

    private func findReaderTextView(in view: UIView) -> UITextView? {
        if let textView = view as? UITextView,
           textView.accessibilityIdentifier == "reader-text-view" {
            return textView
        }
        for subview in view.subviews {
            if let textView = findReaderTextView(in: subview) {
                return textView
            }
        }
        return nil
    }
}

/// Shared by the reader and the current-article summary so their floating
/// controls always keep the same native glass, sizing and press feedback.
struct GlassIconControl: View {
    let symbol: String
    let label: String
    let action: () -> Void
    let isEnabled: Bool

    init(symbol: String, label: String, action: @escaping () -> Void, isEnabled: Bool = true) {
        self.symbol = symbol
        self.label = label
        self.action = action
        self.isEnabled = isEnabled
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .contentShape(Circle())
        .buttonStyle(ReaderBounceButtonStyle())
        .disabled(!isEnabled)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}

struct ReaderBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.interactiveSpring(duration: 0.18, extraBounce: 0.18), value: configuration.isPressed)
    }
}
