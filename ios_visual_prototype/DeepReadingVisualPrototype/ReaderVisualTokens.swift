import SwiftUI

#if DEBUG

enum ReaderVisualTokens {
    static let readerWidth: CGFloat = 393
    static let readerHeight: CGFloat = 852
    static let background = Color(hex: 0xF8F5EF)
    static let progressiveBlurTint = Color(hex: 0xF2F2F7)
    static let primaryText = Color(hex: 0x1D1D1F)
    static let highlight = Color(hex: 0xF2C42E)
    static let horizontalInset: CGFloat = 28
    static let readableWidth: CGFloat = 337
    static let titleSize: CGFloat = 30
    static let bodySize: CGFloat = 20
    static let bodyLineSpacing: CGFloat = 8
    static let paragraphSpacing: CGFloat = 30
    static let circularControlSize: CGFloat = 44
    static let toolbarWidth: CGFloat = 119
    static let topControlY: CGFloat = 52
    static let bottomControlY: CGFloat = 780
    static let topProgressiveBlurHeight: CGFloat = 148
    static let bottomSoftEdgeHeight: CGFloat = 98
}
#endif

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
