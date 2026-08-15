import XCTest
@testable import DeepReadingVisualPrototype

final class ReaderPrototypeModelTests: XCTestCase {
    func testStaticArticleKeepsIntroBeforeImageAndRemainingParagraphsAfterIt() {
        let blocks = ReaderPrototypeState.initial.article.blocks

        XCTAssertEqual(blocks.first?.kind, .paragraph)
        XCTAssertEqual(blocks.first?.text, "人类世界，和物理学一样，可以简化为四种根本的力量：文化、政治、战争和商业。这个排序，基本上也是按照力量由强到弱、可理解性由深到浅、以及相互融合程度由少到多的顺序。下图是我心智模型的可视化展示：")
        XCTAssertEqual(blocks[1].kind, .image)
        XCTAssertEqual(blocks[1].imageName, "FourForces")
        XCTAssertEqual(blocks[2].text, "文化是最神秘、最难解读、最强大的力量。它涵盖了种族、语言、宗教这些让人头疼的难题。")
    }

    func testFocusStateHidesEveryFloatingControl() {
        XCTAssertFalse(ReaderPrototypeState.initial.focused.controlsAreVisible)
    }

    func testPreviewFrameUsesOnlyKnownFrameNames() {
        XCTAssertEqual(ReaderPrototypeState.preview(frameName: "tagManager").frame, .tagManager)
        XCTAssertEqual(ReaderPrototypeState.preview(frameName: "unknown").frame, .controlsVisible)
    }

    func testDownwardScrollHidesChromeAndStatusBarButKeepsAIVisible() {
        var state = ReaderPrototypeState.initial

        state.handleScroll(.down)

        XCTAssertFalse(state.readerChromeIsVisible)
        XCTAssertTrue(state.aiControlIsVisible)
        XCTAssertTrue(state.shouldHideStatusBar)
    }

    func testUpwardScrollRestoresChromeAndStatusBar() {
        var state = ReaderPrototypeState.initial
        state.handleScroll(.down)

        state.handleScroll(.up)

        XCTAssertTrue(state.readerChromeIsVisible)
        XCTAssertTrue(state.aiControlIsVisible)
        XCTAssertFalse(state.shouldHideStatusBar)
    }

    func testBodyTapTogglesTheReaderChrome() {
        var state = ReaderPrototypeState.initial

        state.toggleReaderChrome()
        XCTAssertFalse(state.readerChromeIsVisible)

        state.toggleReaderChrome()
        XCTAssertTrue(state.readerChromeIsVisible)
    }
}
