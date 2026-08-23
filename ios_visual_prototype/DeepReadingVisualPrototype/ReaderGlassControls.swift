import SwiftUI

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
        // iPhone 16 Figma frame: controls at y=780, h=44. With an 852pt
        // canvas this is 28pt from the lower edge; the 8pt top pad retains
        // the 80pt control region while placing the content exactly there.
        .padding(.top, 8)
        .padding(.bottom, 28)
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
