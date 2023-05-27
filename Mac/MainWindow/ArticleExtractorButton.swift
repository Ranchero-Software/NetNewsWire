//
//  ArticleExtractorButton.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

enum ArticleExtractorButtonState {
	case error
	case animated
	case on
	case off
}

@MainActor final class ArticleExtractorButton: NSButton {
	
	public var rightClickAction: Selector?
	
	private var animatedLayer: CALayer?
	
	var buttonState: ArticleExtractorButtonState = .off {
		didSet {
			if buttonState != oldValue {
				switch buttonState {
				case .error:
					stripAnimatedSublayer()
					image = AppAssets.articleExtractorError
				case .animated:
					image = nil
					needsLayout = true
				case .on:
					stripAnimatedSublayer()
					image = AppAssets.articleExtractorOn
				case .off:
					stripAnimatedSublayer()
					image = AppAssets.articleExtractorOff
				}
			}
		}
	}
	
	override func accessibilityLabel() -> String? {
		switch buttonState {
		case .error:
			return NSLocalizedString("label.text.error-reader-view", comment: "Error - Reader View")
		case .animated:
			return NSLocalizedString("label.text.processing-reader-view", comment: "Processing - Reader View")
		case .on:
			return NSLocalizedString("label.text.selected-reader-view", comment: "Selected - Reader View")
		case .off:
			return NSLocalizedString("label.text.reader-view", comment: "Reader View")
		}
	}

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	private func commonInit() {
		wantsLayer = true
		bezelStyle = .texturedRounded
		image = AppAssets.articleExtractorOff
		imageScaling = .scaleProportionallyDown
		widthAnchor.constraint(equalTo: heightAnchor).isActive = true
		sendAction(on: [.leftMouseDown, .rightMouseDown])
	}
	
	override func layout() {
		super.layout()
		guard case .animated = buttonState else {
			return
		}
		stripAnimatedSublayer()
		addAnimatedSublayer(to: layer!)
	}
	
	override func rightMouseDown(with event: NSEvent) {
		_ = target?.perform(rightClickAction, with: self)
	}
	
	private func stripAnimatedSublayer() {
		animatedLayer?.removeFromSuperlayer()
	}
	
	private func addAnimatedSublayer(to hostedLayer: CALayer) {
		let image1 = AppAssets.articleExtractorOff.tinted(with: NSColor.controlTextColor)
		let image2 = AppAssets.articleExtractorOn.tinted(with: NSColor.controlTextColor)
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
		animation.values = images
		animation.repeatCount = HUGE
		
		animatedLayer!.add(animation, forKey: "contents")
	}
	
}
