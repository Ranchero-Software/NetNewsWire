//
//  ArticleExtractorButton.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

enum ArticleExtractorButtonState {
	case error
	case animated
	case on
	case off
}

class ArticleExtractorButton: UIButton {
	
	var buttonState: ArticleExtractorButtonState = .off {
		didSet {
			if buttonState != oldValue {
				switch buttonState {
				case .error:
					stripSublayer()
					setImage(AppAssets.articleExtractorError, for: .normal)
				case .animated:
					setImage(nil, for: .normal)
					setNeedsLayout()
				case .on:
					stripSublayer()
					setImage(AppAssets.articleExtractorOn, for: .normal)
				case .off:
					stripSublayer()
					setImage(AppAssets.articleExtractorOff, for: .normal)
				}
			}
		}
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		guard case .animated = buttonState else {
			return
		}
		stripSublayer()
		addAnimatedSublayer(to: layer)
	}
	
	private func stripSublayer() {
		if layer.sublayers?.count ?? 0 > 1 {
			layer.sublayers?.last?.removeFromSuperlayer()
		}
	}
	
	private func addAnimatedSublayer(to hostedLayer: CALayer) {
		let image1 = AppAssets.articleExtractorOffTinted.cgImage!
		let image2 = AppAssets.articleExtractorOnTinted.cgImage!
		let images = [image1, image2, image1]
		
		let imageLayer = CALayer()
		let imageSize = AppAssets.articleExtractorOff.size
		imageLayer.bounds = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
		imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
		
		hostedLayer.addSublayer(imageLayer)
		
		let animation = CAKeyframeAnimation(keyPath: "contents")
		animation.calculationMode = CAAnimationCalculationMode.linear
		animation.keyTimes = [0, 0.5, 1]
		animation.duration = 2
		animation.values = images as [Any]
		animation.repeatCount = HUGE
		
		imageLayer.add(animation, forKey: "contents")
	}
	
}
