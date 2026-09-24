//
//  ImageAnimator.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class ImageTransition: NSObject, UIViewControllerAnimatedTransitioning {

	private weak var webViewController: WebViewController?
	private let duration = 0.4
	var presenting = true
	var originFrame: CGRect!
	var maskFrame: CGRect!
	var originImage: UIImage!

	init(controller: WebViewController) {
		self.webViewController = controller
	}

	func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		return duration
	}

	func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		if presenting {
			animateTransitionPresenting(using: transitionContext)
		} else {
			animateTransitionReturning(using: transitionContext)
		}
	}

	private func animateTransitionPresenting(using transitionContext: UIViewControllerContextTransitioning) {

		let imageView = UIImageView(image: originImage)
		imageView.frame = originFrame

		transitionContext.view(forKey: .from)?.removeFromSuperview()

		transitionContext.containerView.backgroundColor = Assets.Colors.fullScreenBackground
		transitionContext.containerView.addSubview(imageView)

		webViewController?.hideClickedImage()

		UIView.animate(
			withDuration: duration,
			delay: 0.0,
			usingSpringWithDamping: 0.8,
			initialSpringVelocity: 0.2,
			animations: {
				if let imageController = self.imageViewController(forKey: .to, in: transitionContext) {
					imageView.frame = imageController.zoomedFrame
				}
			}, completion: { _ in
				imageView.removeFromSuperview()
				if let toView = transitionContext.view(forKey: .to) {
					transitionContext.containerView.addSubview(toView)
				}
				transitionContext.completeTransition(true)
		})
	}

	private func animateTransitionReturning(using transitionContext: UIViewControllerContextTransitioning) {

		// The presenting animation removed the destination view from the window,
		// so it must be restored on every path out of here.
		guard let toView = transitionContext.view(forKey: .to) else {
			transitionContext.completeTransition(false)
			return
		}

		guard let imageController = imageViewController(forKey: .from, in: transitionContext),
			  let fromView = transitionContext.view(forKey: .from),
			  let window = fromView.window else {
			transitionContext.containerView.addSubview(toView)
			transitionContext.completeTransition(true)
			return
		}

		let imageView = UIImageView(image: originImage)
		imageView.frame = imageController.zoomedFrame

		let windowFrame = window.frame
		fromView.removeFromSuperview()

		transitionContext.containerView.addSubview(toView)

		let maskingView = UIView()

		let fullMaskFrame = CGRect(x: windowFrame.minX, y: maskFrame.minY, width: windowFrame.width, height: maskFrame.height)
        let path = UIBezierPath(rect: fullMaskFrame)
        let maskLayer = CAShapeLayer()
		maskLayer.path = path.cgPath
		maskingView.layer.mask = maskLayer

		maskingView.addSubview(imageView)
		transitionContext.containerView.addSubview(maskingView)

		UIView.animate(
			withDuration: duration,
			delay: 0.0,
			usingSpringWithDamping: 0.8,
			initialSpringVelocity: 0.2,
			animations: {
				imageView.frame = self.originFrame
			}, completion: { _ in
				if let controller = self.webViewController {
					controller.showClickedImage {
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
							imageView.removeFromSuperview()
							transitionContext.completeTransition(true)
						}
					}
				} else {
					imageView.removeFromSuperview()
					transitionContext.completeTransition(true)
				}
		})
	}

	private func imageViewController(forKey key: UITransitionContextViewControllerKey, in context: UIViewControllerContextTransitioning) -> ImageViewController? {
		let navigationController = context.viewController(forKey: key) as? UINavigationController
		return navigationController?.viewControllers.first as? ImageViewController
	}

}

// The transition is its own transitioning delegate, strongly owned by the presented
// ImageViewController — the WebViewController that configured it can be deallocated
// while the viewer is up, and the dismissal animation must still run to restore the
// view the presenting animation removed.
// <https://github.com/Ranchero-Software/NetNewsWire/issues/3641>
extension ImageTransition: UIViewControllerTransitioningDelegate {

	func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.presenting = true
		return self
	}

	func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.presenting = false
		return self
	}
}
