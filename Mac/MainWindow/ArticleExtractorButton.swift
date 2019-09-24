//
//  ArticleExtractorButton.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

class ArticleExtractorButton: NSButton {
	
	var isError = false {
		didSet {
			if isError != oldValue {
				needsDisplay = true
			}
		}
	}
	
	var isInProgress = false {
		didSet {
			if isInProgress != oldValue {
				needsDisplay = true
			}
		}
	}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		wantsLayer = true
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		wantsLayer = true
	}

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)
		
		guard let hostedLayer = self.layer else {
			return
		}

		if let imageLayer = hostedLayer.sublayers?[0] {
			if needsToDraw(imageLayer.bounds) {
				imageLayer.removeFromSuperlayer()
			} else {
				return
			}
		}

		let opacity: Float = isEnabled ? 1.0 : 0.5
		
		switch true {
		case isError:
			addImageSublayer(to: hostedLayer, image: AppAssets.articleExtractorError, opacity: opacity)
		case isInProgress:
			addAnimatedSublayer(to: hostedLayer)
		default:
			addImageSublayer(to: hostedLayer, image: AppAssets.articleExtractor, opacity: opacity)
		}
	}
	
	private func makeLayerForImage(_ image: NSImage) -> CALayer {
		let imageLayer = CALayer()
		imageLayer.bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
		imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
		return imageLayer
	}
	
	private func addImageSublayer(to hostedLayer: CALayer, image: NSImage, opacity: Float = 1.0) {
		let imageLayer = makeLayerForImage(image)
		imageLayer.contents = image
		imageLayer.opacity = opacity
		hostedLayer.addSublayer(imageLayer)
	}
	
	private func addAnimatedSublayer(to hostedLayer: CALayer) {
		let imageProgress1 = AppAssets.articleExtractorProgress1
		let imageProgress2 = AppAssets.articleExtractorProgress2
		let imageProgress3 = AppAssets.articleExtractorProgress3
		let imageProgress4 = AppAssets.articleExtractorProgress4
		let images = [imageProgress1, imageProgress2, imageProgress3, imageProgress4, imageProgress3, imageProgress2]
		
		let imageLayer = CALayer()
		imageLayer.bounds = CGRect(x: 0, y: 0, width: imageProgress1?.size.width ?? 0, height: imageProgress1?.size.height ?? 0)
		imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
		
		hostedLayer.addSublayer(imageLayer)
		
		let animation = CAKeyframeAnimation(keyPath: "contents")
		animation.calculationMode = CAAnimationCalculationMode.linear
		animation.keyTimes = [0, 0.2, 0.4, 0.6, 0.8, 1]
		animation.duration = 2
		animation.values = images as [Any]
		animation.repeatCount = HUGE
		
		imageLayer.add(animation, forKey: "contents")
	}
	
}
