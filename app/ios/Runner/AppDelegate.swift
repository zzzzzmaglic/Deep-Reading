import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReaderGlassControls") {
      ReaderGlassControlFactory.register(with: registrar)
    }
  }
}

final class ReaderGlassControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      ReaderGlassControlFactory(messenger: registrar.messenger()),
      withId: "deep-reading/reader-glass-control"
    )
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let kind = (args as? [String: Any])?["kind"] as? String ?? "aiBackground"
    let channel = FlutterMethodChannel(
      name: "deep-reading/reader-glass-control",
      binaryMessenger: messenger
    )
    return ReaderGlassControlPlatformView(frame: frame, kind: kind) { action in
      channel.invokeMethod("action", arguments: action)
    }
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class ReaderGlassControlPlatformView: NSObject, FlutterPlatformView {
  private let controlView: ReaderGlassControlView

  init(frame: CGRect, kind: String, actionHandler: @escaping (String) -> Void) {
    controlView = ReaderGlassControlView(
      frame: frame,
      kind: ReaderGlassControlView.Kind(rawValue: kind) ?? .aiBackground,
      actionHandler: actionHandler
    )
    super.init()
  }

  func view() -> UIView {
    controlView
  }
}

final class ReaderGlassControlView: UIView {
  enum Kind: String {
    case back
    case summary
    case toolsBackground
    case aiBackground
  }

  let effectView: UIVisualEffectView
  private let kind: Kind
  private let actionHandler: (String) -> Void

  init(
    frame: CGRect = .zero,
    kind: Kind,
    actionHandler: @escaping (String) -> Void
  ) {
    self.kind = kind
    self.actionHandler = actionHandler
    if #available(iOS 26.0, *) {
      effectView = UIVisualEffectView(effect: UIGlassEffect(style: .clear))
    } else {
      effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialLight))
    }
    super.init(frame: frame)

    clipsToBounds = true
    layer.cornerCurve = .continuous
    effectView.frame = bounds
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    effectView.clipsToBounds = true
    addSubview(effectView)
    installButtonIfNeeded()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let radius = bounds.height / 2
    layer.cornerRadius = radius
    effectView.layer.cornerRadius = radius
  }

  private func installButtonIfNeeded() {
    let symbolName: String
    switch kind {
    case .back:
      symbolName = "chevron.left"
    case .summary:
      symbolName = "ellipsis"
    case .toolsBackground, .aiBackground:
      isUserInteractionEnabled = false
      return
    }

    let button = UIButton(type: .system)
    button.setImage(UIImage(systemName: symbolName), for: .normal)
    button.tintColor = .label
    button.frame = bounds
    button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    button.addTarget(self, action: #selector(handleButtonTap), for: .touchUpInside)
    effectView.contentView.addSubview(button)
  }

  @objc private func handleButtonTap(_ sender: UIButton) {
    UIView.animateKeyframes(
      withDuration: 0.18,
      delay: 0,
      options: [.calculationModeCubic],
      animations: {
        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
          sender.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
        UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4) {
          sender.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        }
        UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
          sender.transform = .identity
        }
      }
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
      self?.dispatchAction()
    }
  }

  private func dispatchAction() {
    switch kind {
    case .back:
      actionHandler("back")
    case .summary:
      actionHandler("summary")
    case .toolsBackground, .aiBackground:
      return
    }
  }
}
