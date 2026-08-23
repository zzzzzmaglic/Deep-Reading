import UIKit

/// Creates the native edit-menu entries for a TextKit selection. The caller
/// owns the selected range so actions always use UITextView's UTF-16 offsets.
enum ReaderSelectionMenu {
    static func makeMenu(
        perform: @escaping (ReaderSelectionAction) -> Void
    ) -> UIMenu {
        UIMenu(children: [
            UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { _ in
                perform(.copy)
            },
            UIAction(title: "划线", image: UIImage(systemName: "highlighter")) { _ in
                perform(.highlight)
            },
            UIAction(title: "打开资产卡片", image: UIImage(systemName: "note.text")) { _ in
                perform(.openAssetCard)
            },
            UIAction(title: "AI 释义", image: UIImage(systemName: "sparkles")) { _ in
                perform(.explainWithAI)
            },
        ])
    }

    static func makeHighlightedMenu(
        perform: @escaping (ReaderSelectionAction) -> Void
    ) -> UIMenu {
        UIMenu(children: [
            UIAction(title: "取消划线", image: UIImage(systemName: "highlighter.slash"), attributes: .destructive) { _ in
                perform(.removeHighlight)
            },
            UIAction(title: "打开资产卡片", image: UIImage(systemName: "note.text")) { _ in
                perform(.openAssetCard)
            },
            UIAction(title: "AI 释义", image: UIImage(systemName: "sparkles")) { _ in
                perform(.explainWithAI)
            },
            UIAction(title: "复制", image: UIImage(systemName: "doc.on.doc")) { _ in
                perform(.copy)
            },
            UIAction(title: "标签管理", image: UIImage(systemName: "tag")) { _ in
                perform(.manageTags)
            },
        ])
    }
}
