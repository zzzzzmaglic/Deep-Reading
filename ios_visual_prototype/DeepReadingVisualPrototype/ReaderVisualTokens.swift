import SwiftUI

enum ReaderVisualTokens {
    static let readerWidth: CGFloat = 393
    static let readerHeight: CGFloat = 852
    static let background = Color(hex: 0xF8F5EF)
    static let primaryText = Color(hex: 0x1D1D1F)
    static let highlight = Color(hex: 0xF2C42E)
    static let horizontalInset: CGFloat = 28
    static let readableWidth: CGFloat = 337
    static let titleSize: CGFloat = 28
    static let bodySize: CGFloat = 21
    static let bodyLineSpacing: CGFloat = 6
    static let paragraphSpacing: CGFloat = 10
    static let circularControlSize: CGFloat = 44
    static let toolbarWidth: CGFloat = 119
    static let topControlY: CGFloat = 52
    static let bottomControlY: CGFloat = 780
}

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
