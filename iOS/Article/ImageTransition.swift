//
//  ImageAnimator.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ImageTransition: NSObject, UIViewControllerAnimatedTransitioning {

	let duration = 0.3
	var presenting = true
	var originFrame: CGRect!
	var originImage: UIImage!
	
	func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		return duration
	}
	
	func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		
		let destFrame: CGRect = {
			if presenting {
				let imageController = transitionContext.viewController(forKey: .to) as! ImageViewController
				return imageController.zoomedFrame
			} else {
				let imageController = transitionContext.viewController(forKey: .from) as! ImageViewController
				return imageController.zoomedFrame
			}
		}()
	
		let initialFrame = presenting ? originFrame! : destFrame
		let targetFrame = presenting ? destFrame : originFrame!

		let imageView = UIImageView(image: originImage)
		imageView.frame = initialFrame
		
		let fromView = transitionContext.view(forKey: .from)!
		fromView.removeFromSuperview()
		
		transitionContext.containerView.backgroundColor = UIColor.systemBackground
		transitionContext.containerView.addSubview(imageView)

		UIView.animate(
			withDuration: duration,
			delay:0.0,
			usingSpringWithDamping: 0.8,
			initialSpringVelocity: 0.2,
			animations: {
				imageView.frame = targetFrame
			}, completion: { _ in
				imageView.removeFromSuperview()
				let toView = transitionContext.view(forKey: .to)!
				transitionContext.containerView.addSubview(toView)
				transitionContext.containerView.bringSubviewToFront(toView)
				transitionContext.completeTransition(true)
		})
		
	}
	
}
