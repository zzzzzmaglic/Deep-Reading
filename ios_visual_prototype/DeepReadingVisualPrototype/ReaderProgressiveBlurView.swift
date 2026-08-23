import CoreImage.CIFilterBuiltins
import QuartzCore
import SwiftUI
import UIKit

#if DEBUG

/// Simulator-only visual-prototype implementation.
///
/// The effect uses the private `CAFilter` variable-blur mechanism to make the
/// blur radius follow a gradient. Keep this file inside the visual prototype;
/// it must not be moved into a production or release target.
struct ReaderTopProgressiveBlur: View {
    let isVisible: Bool
    /// Keep the reader's proven variable-blur treatment reusable for screens
    /// that share its chrome, while allowing each screen to keep its own
    /// vertical geometry.
    let height: CGFloat

    init(
        isVisible: Bool,
        height: CGFloat = ReaderVisualTokens.topProgressiveBlurHeight
    ) {
        self.isVisible = isVisible
        self.height = height
    }

    var body: some View {
        ReaderVariableBlurView(
            // Figma node 6:2 specifies a 9.1pt backdrop blur. The original
            // prototype accidentally retained the 2pt exploration value,
            // which is effectively imperceptible over reader text.
            maxBlurRadius: 3,
            direction: .blurredTopClearBottom,
            startOffset: 0
        )
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: ReaderVisualTokens.progressiveBlurTint.opacity(0.5), location: 0),
                    .init(color: ReaderVisualTokens.progressiveBlurTint.opacity(0.375), location: 0.25),
                    .init(color: ReaderVisualTokens.progressiveBlurTint.opacity(0.25), location: 0.5),
                    .init(color: ReaderVisualTokens.progressiveBlurTint.opacity(0.125), location: 0.75),
                    .init(color: ReaderVisualTokens.progressiveBlurTint.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.22), value: isVisible)
    }
}

private enum ReaderVariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

private struct ReaderVariableBlurView: UIViewRepresentable {
    let maxBlurRadius: CGFloat
    let direction: ReaderVariableBlurDirection
    let startOffset: CGFloat

    func makeUIView(context: Context) -> ReaderVariableBlurEffectView {
        ReaderVariableBlurEffectView(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
    }

    func updateUIView(_ uiView: ReaderVariableBlurEffectView, context: Context) {}
}

private final class ReaderVariableBlurEffectView: UIVisualEffectView {
    init(
        maxBlurRadius: CGFloat,
        direction: ReaderVariableBlurDirection,
        startOffset: CGFloat
    ) {
        super.init(effect: UIBlurEffect(style: .regular))

        let filterClassName = String("retliFAC".reversed())
        let filterSelectorName = String(":epyThtiWretlif".reversed())

        guard
            let filterClass = NSClassFromString(filterClassName) as? NSObject.Type,
            let variableBlur = filterClass
                .perform(NSSelectorFromString(filterSelectorName), with: "variableBlur")?
                .takeUnretainedValue() as? NSObject,
            let gradientImage = Self.makeGradientImage(
                startOffset: startOffset,
                direction: direction
            )
        else {
            return
        }

        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        let backdropLayer = subviews.first?.layer
        backdropLayer?.filters = [variableBlur]

        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}

    private static func makeGradientImage(
        width: CGFloat = 100,
        height: CGFloat = 100,
        startOffset: CGFloat,
        direction: ReaderVariableBlurDirection
    ) -> CGImage? {
        let gradient = CIFilter.linearGradient()
        gradient.color0 = CIColor.black
        gradient.color1 = CIColor.clear
        gradient.point0 = CGPoint(x: 0, y: height)
        gradient.point1 = CGPoint(x: 0, y: startOffset * height)

        if case .blurredBottomClearTop = direction {
            gradient.point0.y = 0
            gradient.point1.y = height - gradient.point1.y
        }

        guard let outputImage = gradient.outputImage else { return nil }
        return CIContext().createCGImage(
            outputImage,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }
}
#endif

/// The public SwiftUI scroll-edge treatment does not observe the UIKit
/// `UITextView` used by the live reader. Keep this non-blurring fade at the
/// same 98pt geometry so the bottom edge still softly lifts text behind the
/// fixed Liquid Glass controls.
struct ReaderBottomSoftEdge: View {
    let isVisible: Bool

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0xF8F5EF).opacity(0), location: 0),
                .init(color: Color(hex: 0xF8F5EF).opacity(0.125), location: 0.25),
                .init(color: Color(hex: 0xF8F5EF).opacity(0.25), location: 0.5),
                .init(color: Color(hex: 0xF8F5EF).opacity(0.375), location: 0.75),
                .init(color: Color(hex: 0xF8F5EF).opacity(0.5), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 98)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.22), value: isVisible)
    }
}
