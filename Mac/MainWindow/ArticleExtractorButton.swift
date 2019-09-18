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
			needsDisplay = true
		}
	}
	
	var isInProgress = false {
		didSet {
			needsDisplay = true
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
			addImageSublayer(to: hostedLayer, imageName: "articleExtractorError", opacity: opacity)
		case isInProgress:
			addProgressSublayer(to: hostedLayer)
		default:
			addImageSublayer(to: hostedLayer, imageName: "articleExtractor", opacity: opacity)
		}
		
	}
	
	private func makeLayerForImage(_ image: NSImage) -> CALayer {
		let imageLayer = CALayer()
		imageLayer.bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
		imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
		return imageLayer
	}
	
	private func addImageSublayer(to hostedLayer: CALayer, imageName: String, opacity: Float = 1.0) {
		
		guard let image = NSImage(named: imageName) else {
			fatalError("Image doesn't exist: \(imageName)")
		}
		
		let imageLayer = makeLayerForImage(image)
		imageLayer.contents = image
		imageLayer.opacity = opacity
		hostedLayer.addSublayer(imageLayer)
		
	}
	
	private func addProgressSublayer(to hostedLayer: CALayer) {
		
		let imageProgress1 = NSImage(named: "articleExtractorProgress1")
		let imageProgress2 = NSImage(named: "articleExtractorProgress2")
		let imageProgress3 = NSImage(named: "articleExtractorProgress3")
		let imageProgress4 = NSImage(named: "articleExtractorProgress4")
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
