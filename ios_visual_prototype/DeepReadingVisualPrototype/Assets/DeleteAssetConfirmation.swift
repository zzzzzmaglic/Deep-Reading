import SwiftUI

struct DeleteAssetConfirmation: View {
    let isOperationInFlight: Bool
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        AssetCardConfirmationDialog(
            title: "确认删除该阅读资产？",
            message: "删除后将无法恢复。",
            primaryTitle: "取消",
            primaryAction: cancel,
            destructiveTitle: "删除",
            destructiveAction: confirm,
            isOperationInFlight: isOperationInFlight,
            destructiveAccessibilityIdentifier: "asset-delete-confirm"
        )
    }
}

/// Shared fixed-geometry alert used by Figma 05a and 06d. It deliberately
/// avoids SwiftUI's system alert so typography, dividers, and 313×202 size
/// remain identical to the delivery frames.
struct AssetCardConfirmationDialog: View {
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let destructiveTitle: String
    let destructiveAction: () -> Void
    let isOperationInFlight: Bool
    let destructiveAccessibilityIdentifier: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !isOperationInFlight else { return }
                    primaryAction()
                }

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(uiColor: .label))
                        .frame(width: 220, height: 23, alignment: .leading)

                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .frame(width: 260, height: 40, alignment: .topLeading)
                        .padding(.top, 13)
                }
                .padding(.leading, 27)
                .padding(.top, 28)

                Spacer(minLength: 0)
                    .frame(height: 28)

                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(width: 313, height: 1)

                HStack(spacing: 0) {
                    Button(primaryTitle, action: primaryAction)
                        .frame(width: 156, height: 69)
                        .foregroundStyle(Color(uiColor: .systemBlue))

                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(width: 1, height: 69)

                    Button(destructiveTitle, role: .destructive, action: destructiveAction)
                        .frame(width: 156, height: 69)
                        .foregroundStyle(Color(uiColor: .systemRed))
                        .accessibilityIdentifier(destructiveAccessibilityIdentifier)
                }
                .font(.system(size: 17, weight: .medium))
            }
            .disabled(isOperationInFlight)
            .frame(width: 313, height: 202, alignment: .topLeading)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
}
