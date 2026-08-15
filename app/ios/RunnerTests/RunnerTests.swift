import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testReaderGlassControlUsesLiquidGlassOnIOS26() {
    let view = ReaderGlassControlView(kind: .back, actionHandler: { _ in })

    if #available(iOS 26.0, *) {
      XCTAssertTrue(view.effectView.effect is UIGlassEffect)
    }
  }

  func testReaderGlassControlRoundsItselfAfterPlatformViewLayout() {
    let view = ReaderGlassControlView(kind: .back, actionHandler: { _ in })
    view.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
    view.layoutIfNeeded()

    XCTAssertEqual(view.layer.cornerRadius, 22, accuracy: 0.001)
    XCTAssertEqual(view.effectView.layer.cornerRadius, 22, accuracy: 0.001)
  }

}
