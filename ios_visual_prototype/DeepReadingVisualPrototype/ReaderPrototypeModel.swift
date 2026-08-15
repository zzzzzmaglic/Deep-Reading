import Foundation

enum ReaderFrame: String, CaseIterable {
    case controlsVisible
    case focused
    case textSelection
    case highlighted
    case assetCard
    case assetEditor
    case tagManager
    case newTag
}

enum ReaderScrollDirection {
    case up
    case down
}

enum PrototypeArticleBlockKind: Equatable {
    case paragraph
    case image
}

struct PrototypeArticleBlock: Identifiable, Equatable {
    let id: String
    let kind: PrototypeArticleBlockKind
    let text: String
    let imageName: String?

    static func paragraph(_ id: String, _ text: String) -> PrototypeArticleBlock {
        PrototypeArticleBlock(id: id, kind: .paragraph, text: text, imageName: nil)
    }

    static func image(_ id: String, name: String) -> PrototypeArticleBlock {
        PrototypeArticleBlock(id: id, kind: .image, text: "", imageName: name)
    }
}

struct PrototypeArticle: Equatable {
    let title: String
    let blocks: [PrototypeArticleBlock]
}

struct ReaderPrototypeState: Equatable {
    var article: PrototypeArticle
    var frame: ReaderFrame

    static let initial = ReaderPrototypeState(article: .demo, frame: .controlsVisible)

    static func preview(frameName: String?) -> ReaderPrototypeState {
        ReaderPrototypeState(
            article: .demo,
            frame: frameName.flatMap(ReaderFrame.init(rawValue:)) ?? .controlsVisible
        )
    }

    var controlsAreVisible: Bool {
        readerChromeIsVisible
    }

    var readerChromeIsVisible: Bool {
        switch frame {
        case .controlsVisible, .assetCard, .assetEditor, .tagManager, .newTag:
            return true
        case .focused, .textSelection, .highlighted:
            return false
        }
    }

    var aiControlIsVisible: Bool {
        switch frame {
        case .controlsVisible, .focused:
            true
        case .assetCard, .assetEditor, .tagManager, .newTag:
            true
        case .textSelection, .highlighted:
            false
        }
    }

    var shouldHideStatusBar: Bool {
        !controlsAreVisible
    }

    var focused: ReaderPrototypeState {
        var copy = self
        copy.frame = .focused
        return copy
    }

    mutating func show(_ frame: ReaderFrame) {
        self.frame = frame
    }

    mutating func handleScroll(_ direction: ReaderScrollDirection) {
        switch (frame, direction) {
        case (.controlsVisible, .down):
            frame = .focused
        case (.focused, .up):
            frame = .controlsVisible
        default:
            break
        }
    }

    mutating func toggleReaderChrome() {
        switch frame {
        case .controlsVisible:
            frame = .focused
        case .focused:
            frame = .controlsVisible
        default:
            break
        }
    }
}

private extension PrototypeArticle {
    static let demo = PrototypeArticle(
        title: "1600-2100年的公司简史",
        blocks: [
            .paragraph("intro", "人类世界，和物理学一样，可以简化为四种根本的力量：文化、政治、战争和商业。这个排序，基本上也是按照力量由强到弱、可理解性由深到浅、以及相互融合程度由少到多的顺序。下图是我心智模型的可视化展示："),
            .image("four-forces", name: "FourForces"),
            .paragraph("culture", "文化是最神秘、最难解读、最强大的力量。它涵盖了种族、语言、宗教这些让人头疼的难题。"),
            .paragraph("commerce", "而商业呢，就像物理学中的万有引力，看似微不足道，却蕴含着基本的规律和原则——这些原则简单到连高中生都能理解，它们决定了公司的结构，以及宏观经济指标、微观经济平衡表、年度报告和股市数据等描述性概念。"),
            .paragraph("gravity", "但是，万有引力之所以在宇宙尺度上占据主导地位，是因为它对所有物体都有吸引力，而且从不排斥。所以，尽管力量微弱，但它在足够大的尺度上却能发挥决定性作用。我并不想把这个比喻扯得太远，但商业的确有类似的特点。"),
            .paragraph("daily-life", "在日常生活中，文化、政治和战争的影响似乎举足轻重。但如果我们将时间线拉长至数日或数周，这些因素实际上会在历史的长河中相互抵消，最终变得微不足道。从历史的角度来看，它们更像是短暂的杂音，而非持续的信号。它们并不会带来那种创造性破坏式的单向变革。")
        ]
    )
}
