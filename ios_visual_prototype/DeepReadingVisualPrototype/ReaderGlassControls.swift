import SwiftUI

struct ReaderTopGlassControls: View {
    let onBack: () -> Void

    init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }

    var body: some View {
        HStack {
            GlassIconControl(symbol: "chevron.left", label: "返回", action: onBack)
            Spacer()
            // Summary is introduced in Stage F; retain only the approved visual affordance.
            GlassIconControl(symbol: "doc.text.magnifyingglass", label: "汇总（即将推出）", action: {}, isEnabled: false)
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
        .padding(.top, 6)
        .padding(.bottom, 30)
    }
}

private struct GlassIconControl: View {
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
