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
	
	private var animatedLayer: CALayer?
	
	var buttonState: ArticleExtractorButtonState = .off {
		didSet {
			if buttonState != oldValue {
				switch buttonState {
				case .error:
					stripAnimatedSublayer()
					setImage(AppAssets.articleExtractorError, for: .normal)
				case .animated:
					setImage(nil, for: .normal)
					setNeedsLayout()
				case .on:
					stripAnimatedSublayer()
					setImage(AppAssets.articleExtractorOn, for: .normal)
				case .off:
					stripAnimatedSublayer()
					setImage(AppAssets.articleExtractorOff, for: .normal)
				}
			}
		}
	}
	
	override var accessibilityLabel: String? {
		get {
			switch buttonState {
			case .error:
				return NSLocalizedString("Error - Reader View", comment: "Error - Reader View")
			case .animated:
				return NSLocalizedString("Processing - Reader View", comment: "Processing - Reader View")
			case .on:
				return NSLocalizedString("Selected - Reader View", comment: "Selected - Reader View")
			case .off:
				return NSLocalizedString("Reader View", comment: "Reader View")
			}
		}
		set {
			super.accessibilityLabel = newValue
		}
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		guard case .animated = buttonState else {
			return
		}
		stripAnimatedSublayer()
		addAnimatedSublayer(to: layer)
	}
	
	private func stripAnimatedSublayer() {
		animatedLayer?.removeFromSuperlayer()
	}
	
	private func addAnimatedSublayer(to hostedLayer: CALayer) {
		let image1 = AppAssets.articleExtractorOffTinted.cgImage!
		let image2 = AppAssets.articleExtractorOnTinted.cgImage!
		let images = [image1, image2, image1]
		
		animatedLayer = CALayer()
		let imageSize = AppAssets.articleExtractorOff.size
		animatedLayer!.bounds = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
		animatedLayer!.position = CGPoint(x: bounds.midX, y: bounds.midY)
		
		hostedLayer.addSublayer(animatedLayer!)
		
		let animation = CAKeyframeAnimation(keyPath: "contents")
		animation.calculationMode = CAAnimationCalculationMode.linear
		animation.keyTimes = [0, 0.5, 1]
		animation.duration = 2
		animation.values = images as [Any]
		animation.repeatCount = HUGE
		
		animatedLayer!.add(animation, forKey: "contents")
	}
	
}
