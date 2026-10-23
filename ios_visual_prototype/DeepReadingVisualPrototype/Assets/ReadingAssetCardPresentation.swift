import SwiftUI
import UIKit

/// Presents SwiftUI reading-asset content with UIKit's public custom
/// presentation stack. UIKit owns the dimming view, while the hosted SwiftUI
/// layer moves independently, so the backdrop fades instead of sliding up with
/// the card.
struct ReadingAssetCardUIKitPresenter<Item: Identifiable, PresentedContent: View>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let transitionStyle: ReadingOverlayTransitionStyle
    let content: (Item) -> PresentedContent

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> ReadingAssetPresentationAnchorController {
        let controller = ReadingAssetPresentationAnchorController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.onReady = { [weak coordinator = context.coordinator] in
            coordinator?.reconcilePresentation()
        }
        context.coordinator.anchorController = controller
        return controller
    }

    func updateUIViewController(
        _ uiViewController: ReadingAssetPresentationAnchorController,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.anchorController = uiViewController
        context.coordinator.reconcilePresentation()
    }

    static func dismantleUIViewController(
        _ uiViewController: ReadingAssetPresentationAnchorController,
        coordinator: Coordinator
    ) {
        coordinator.dismissImmediately()
        uiViewController.onReady = nil
    }

    @MainActor
    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var parent: ReadingAssetCardUIKitPresenter
        weak var anchorController: ReadingAssetPresentationAnchorController?

        private weak var presentedController: UIViewController?
        private weak var presentedHostingController: UIHostingController<PresentedContent>?
        private var presentedID: AnyHashable?
        private var transitioningDelegate: ReadingAssetCardTransitioningDelegate?
        private var isPresenting = false
        private var isDismissing = false

        init(parent: ReadingAssetCardUIKitPresenter) {
            self.parent = parent
        }

        func reconcilePresentation() {
            guard let anchorController,
                  anchorController.viewIfLoaded?.window != nil else { return }

            if let item = parent.item {
                let itemID = AnyHashable(item.id)
                if presentedID == itemID {
                    presentedHostingController?.rootView = parent.content(item)
                    return
                }
                guard !isPresenting, !isDismissing else { return }

                if presentedController != nil {
                    dismissPresentedController(animated: false) { [weak self] in
                        self?.reconcilePresentation()
                    }
                } else {
                    present(item, id: itemID, from: anchorController)
                }
            } else if presentedController != nil, !isDismissing {
                dismissPresentedController(animated: parent.transitionStyle.animatesDismissal)
            }
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            clearPresentedState()
            if parent.item != nil {
                parent.item = nil
            }
        }

        func dismissImmediately() {
            guard let presentedController else { return }
            presentedController.dismiss(animated: false)
            clearPresentedState()
        }

        private func present(
            _ item: Item,
            id: AnyHashable,
            from anchorController: UIViewController
        ) {
            guard let presenter = topPresenter(for: anchorController) else { return }

            let hostingController = UIHostingController(rootView: parent.content(item))
            hostingController.view.backgroundColor = .clear
            hostingController.view.isOpaque = false
            hostingController.view.accessibilityViewIsModal = true
            hostingController.modalPresentationStyle = .custom
            hostingController.modalPresentationCapturesStatusBarAppearance = false

            let transitioningDelegate = ReadingAssetCardTransitioningDelegate(style: parent.transitionStyle)
            hostingController.transitioningDelegate = transitioningDelegate
            self.transitioningDelegate = transitioningDelegate
            presentedController = hostingController
            presentedHostingController = hostingController
            presentedID = id
            isPresenting = true

            presenter.present(hostingController, animated: true) { [weak self, weak hostingController] in
                guard let self else { return }
                self.isPresenting = false
                hostingController?.presentationController?.delegate = self
                self.reconcilePresentation()
            }
        }

        private func dismissPresentedController(
            animated: Bool,
            completion: (() -> Void)? = nil
        ) {
            guard let presentedController else {
                clearPresentedState()
                completion?()
                return
            }

            isDismissing = true
            presentedController.dismiss(animated: animated) { [weak self] in
                guard let self else { return }
                self.clearPresentedState()
                completion?()
            }
        }

        private func clearPresentedState() {
            presentedController = nil
            presentedHostingController = nil
            presentedID = nil
            transitioningDelegate = nil
            isPresenting = false
            isDismissing = false
        }

        private func topPresenter(for anchorController: UIViewController) -> UIViewController? {
            guard var presenter = anchorController.viewIfLoaded?.window?.rootViewController else {
                return nil
            }

            while let presented = presenter.presentedViewController,
                  !presented.isBeingDismissed {
                presenter = presented
            }
            return presenter
        }
    }
}

enum ReadingOverlayTransitionStyle: Equatable {
    case assetCard
    case readingReport

    var dimmingOpacity: CGFloat {
        switch self {
        case .assetCard: 0.16
        case .readingReport: 0.20
        }
    }

    var animatesDismissal: Bool {
        self == .assetCard
    }
}

final class ReadingAssetPresentationAnchorController: UIViewController {
    var onReady: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onReady?()
    }
}

private final class ReadingAssetCardTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    private let style: ReadingOverlayTransitionStyle

    init(style: ReadingOverlayTransitionStyle) {
        self.style = style
    }

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        ReadingAssetCardPresentationController(
            presentedViewController: presented,
            presenting: presenting,
            style: style
        )
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ReadingAssetCardTransitionAnimator(isPresenting: true, style: style)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ReadingAssetCardTransitionAnimator(isPresenting: false, style: style)
    }
}

private final class ReadingAssetCardPresentationController: UIPresentationController {
    private let style: ReadingOverlayTransitionStyle
    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }()

    init(
        presentedViewController: UIViewController,
        presenting presentingViewController: UIViewController?,
        style: ReadingOverlayTransitionStyle
    ) {
        self.style = style
        super.init(
            presentedViewController: presentedViewController,
            presenting: presentingViewController
        )
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        containerView?.bounds ?? .zero
    }

    override var shouldPresentInFullscreen: Bool { true }

    override var shouldRemovePresentersView: Bool { false }

    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        guard let containerView else { return }

        dimmingView.frame = containerView.bounds
        containerView.insertSubview(dimmingView, at: 0)

        let changes = { [weak self] in
            guard let self else { return }
            self.dimmingView.alpha = self.style.dimmingOpacity
        }
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in changes() })
        } else {
            changes()
        }
    }

    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        let changes = { [weak self] in
            self?.dimmingView.alpha = 0
        }
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in changes() })
        } else {
            changes()
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        if completed {
            dimmingView.removeFromSuperview()
        }
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard let containerView else { return }
        dimmingView.frame = containerView.bounds
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

private final class ReadingAssetCardTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let isPresenting: Bool
    private let style: ReadingOverlayTransitionStyle

    init(isPresenting: Bool, style: ReadingOverlayTransitionStyle) {
        self.isPresenting = isPresenting
        self.style = style
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        switch style {
        case .assetCard:
            isPresenting ? 0.42 : 0.30
        case .readingReport:
            isPresenting ? 0.22 : 0
        }
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if style == .readingReport {
            animateImmediateReportTransition(using: transitionContext)
            return
        }

        let containerView = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        if isPresenting {
            guard let presentedView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }

            let finalFrame = transitionContext.finalFrame(
                for: transitionContext.viewController(forKey: .to)!
            )
            presentedView.frame = finalFrame
            presentedView.transform = CGAffineTransform(
                translationX: 0,
                y: containerView.bounds.height
            )
            containerView.addSubview(presentedView)

            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: 0.92,
                initialSpringVelocity: 0.2,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                presentedView.transform = .identity
            } completion: { _ in
                let completed = !transitionContext.transitionWasCancelled
                if !completed { presentedView.removeFromSuperview() }
                transitionContext.completeTransition(completed)
            }
        } else {
            guard let presentedView = transitionContext.view(forKey: .from) else {
                transitionContext.completeTransition(false)
                return
            }

            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
            ) {
                presentedView.transform = CGAffineTransform(
                    translationX: 0,
                    y: containerView.bounds.height
                )
            } completion: { _ in
                let completed = !transitionContext.transitionWasCancelled
                if completed { presentedView.removeFromSuperview() }
                transitionContext.completeTransition(completed)
            }
        }
    }

    private func animateImmediateReportTransition(
        using transitionContext: UIViewControllerContextTransitioning
    ) {
        if isPresenting {
            guard let presentedController = transitionContext.viewController(forKey: .to),
                  let presentedView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }
            presentedView.frame = transitionContext.finalFrame(for: presentedController)
            presentedView.transform = .identity
            transitionContext.containerView.addSubview(presentedView)

            // The report itself appears in its final state immediately. Keep
            // the transition context alive only while UIPresentationController
            // fades the independent dimming view, matching the asset-card
            // backdrop without reintroducing a bottom-sheet translation.
            UIView.animate(
                withDuration: transitionDuration(using: transitionContext),
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction]
            ) {
                presentedView.alpha = 1
            } completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else {
            transitionContext.view(forKey: .from)?.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

extension View {
    func readingAssetCardPresentation<Item: Identifiable, PresentedContent: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> PresentedContent
    ) -> some View {
        background {
            ReadingAssetCardUIKitPresenter(
                item: item,
                transitionStyle: .assetCard,
                content: content
            )
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }


    func readingReportPresentation<Item: Identifiable, PresentedContent: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> PresentedContent
    ) -> some View {
        background {
            ReadingAssetCardUIKitPresenter(
                item: item,
                transitionStyle: .readingReport,
                content: content
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }
}
