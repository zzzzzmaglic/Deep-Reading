import SwiftUI

struct ReaderSelectionOverlay: View {
    let underline: () -> Void
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)

            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ReaderVisualTokens.highlight.opacity(0.52))
                    .frame(width: 286, height: 62)

                GlassEffectContainer {
                    HStack(spacing: 16) {
                        Button("划线", action: underline)
                        Button("笔记", action: dismiss)
                        Button("AI 释义", action: dismiss)
                        Button("拷贝", action: dismiss)
                    }
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
            }
            .offset(y: -58)
        }
    }
}

struct ReaderHighlightOverlay: View {
    let openAsset: () -> Void

    var body: some View {
        VStack(spacing: 27) {
            Color.clear.frame(height: 195)
            VStack(spacing: 27) {
                Rectangle().fill(ReaderVisualTokens.highlight).frame(width: 337, height: 4).clipShape(Capsule())
                Rectangle().fill(ReaderVisualTokens.highlight).frame(width: 337, height: 4).clipShape(Capsule())
                Button(action: openAsset) {
                    Rectangle().fill(ReaderVisualTokens.highlight).frame(width: 200, height: 4).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(true)
    }
}

struct ReaderAssetCardOverlay: View {
    let isEditing: Bool
    let beginEditing: () -> Void
    let showTags: () -> Void
    let dismiss: () -> Void
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 16) {
                Text("“商业的确有类似的特点。”")
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                if isEditing {
                    TextField("添加笔记", text: $note, axis: .vertical)
                        .focused($noteFocused)
                        .font(.system(size: 17))
                        .lineLimit(3...5)
                } else {
                    Button("添加笔记") { beginEditing() }
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    Button("#标签", action: showTags)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.blue)
                    Button(role: .destructive, action: {}) {
                        Image(systemName: "trash")
                    }
                    Spacer()
                    GlassEffectContainer {
                        Button(action: beginEditing) {
                            Image(systemName: "pencil")
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: Circle())
                        }
                        .buttonStyle(ReaderBounceButtonStyle())
                    }
                }
            }
            .padding(20)
            .frame(width: 345, height: 460, alignment: .topLeading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28))
            .task(id: isEditing) {
                if isEditing { noteFocused = true }
            }
        }
    }
}

struct ReaderTagSheetOverlay: View {
    let isNewTag: Bool
    let dismiss: () -> Void
    let showNewTag: () -> Void
    @State private var tagName = ""
    @FocusState private var tagFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 0) {
                Capsule().fill(Color.secondary.opacity(0.55)).frame(width: 36, height: 5).padding(.top, 12)
                HStack {
                    Spacer()
                    Text("标签管理").font(.system(size: 18, weight: .bold))
                    Spacer()
                    Button("确定", action: dismiss).font(.system(size: 17, weight: .bold))
                }
                .padding(.horizontal, 24)
                .padding(.top, 13)

                Text("为这条阅读资产选择标签")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 36)

                VStack(spacing: 0) {
                    tagRow("摘录与思考", symbol: "lock.fill")
                    tagRow("深度阅读", symbol: "checkmark")
                    tagRow("商业化", symbol: nil)
                    if isNewTag {
                        TextField("新建标签", text: $tagName)
                            .focused($tagFocused)
                            .padding(.horizontal, 18)
                            .frame(height: 48)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        Button("+ 新建标签", action: showNewTag)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                Spacer()
            }
            .frame(height: isNewTag ? 768 : 426)
            .background(Color(uiColor: .secondarySystemBackground), in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
            .task(id: isNewTag) {
                if isNewTag { tagFocused = true }
            }
        }
    }

    private func tagRow(_ title: String, symbol: String?) -> some View {
        HStack {
            Text(title).font(.system(size: 17))
            Spacer()
            if let symbol {
                Image(systemName: symbol).foregroundStyle(.secondary)
            }
        }
        .frame(height: 48)
    }
}
