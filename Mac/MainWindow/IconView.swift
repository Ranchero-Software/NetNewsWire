//
//  TimelineIconView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Images

final class IconView: NSView {

	var iconImage: IconImage? {
		didSet {
			if iconImage !== oldValue {
				imageView.image = iconImage?.image
				if let tintColor = iconImage?.preferredColor {
					imageView.contentTintColor = tintColor
				}

				if iconImage?.isBackgroundSuppressed ?? false {
					isDiscernable = true
				} else if NSApplication.shared.effectiveAppearance.isDarkMode {
					if iconImage?.isDark ?? false {
						isDiscernable = false
					} else {
						isDiscernable = true
					}
				} else {
					if iconImage?.isBright ?? false {
						isDiscernable = false
					} else {
						isDiscernable = true
					}
				}

				needsDisplay = true
				needsLayout = true
			}
		}
	}

	private var isDiscernable = true

	nonisolated override var isFlipped: Bool {
		return true
	}

	private let imageView: NSImageView = {
		let imageView = NSImageView(frame: NSRect.zero)
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		imageView.imageScaling = .scaleProportionallyUpOrDown
		return imageView
	}()

	private var hasExposedVerticalBackground: Bool {
		return imageView.frame.size.height < bounds.size.height
	}

	private static var lightBackgroundColor = Assets.Colors.iconLightBackground
	private static var darkBackgroundColor = Assets.Colors.iconDarkBackground

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	convenience init() {
		self.init(frame: NSRect.zero)
	}

	override func viewDidMoveToSuperview() {
		needsLayout = true
		needsDisplay = true
	}

	override func layout() {
		resizeSubviews(withOldSize: NSSize.zero)
	}

	override func resizeSubviews(withOldSize oldSize: NSSize) {
		imageView.setFrameIfNotEqual(rectForImageView())
	}

	override func draw(_ dirtyRect: NSRect) {
		guard !(iconImage?.isBackgroundSuppressed ?? false) else { return }
		guard hasExposedVerticalBackground || !isDiscernable else { return }

		let color = NSApplication.shared.effectiveAppearance.isDarkMode ? IconView.darkBackgroundColor : IconView.lightBackgroundColor
		color.set()
		dirtyRect.fill()
	}
}

private extension IconView {

	func commonInit() {
		addSubview(imageView)
		wantsLayer = true
		layer?.cornerRadius = 4.0
	}

	func rectForImageView() -> NSRect {
		guard !(iconImage?.isSymbol ?? false) else {
			return NSRect(x: 0.0, y: 0.0, width: bounds.size.width, height: bounds.size.height)
		}

		guard let image = iconImage?.image else {
			return NSRect.zero
		}

		let imageSize = image.size
		let viewSize = bounds.size
		guard imageSize.width > 0.0, imageSize.height > 0.0 else {
			return NSRect.zero
		}

		// Aspect-fit, but never scale up — small icons render at natural size, centered.
		let factor = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height, 1.0)
		let width = imageSize.width * factor
		let height = imageSize.height * factor
		let originX = floor((viewSize.width - width) / 2.0)
		let originY = floor((viewSize.height - height) / 2.0)
		return NSRect(x: originX, y: originY, width: width, height: height)
	}
}
