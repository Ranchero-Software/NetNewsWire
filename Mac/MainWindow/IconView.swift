//
//  TimelineIconView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class IconView: NSView {

	var iconImage: IconImage? {
		didSet {
			if iconImage !== oldValue {
				imageView.image = iconImage?.image
				if let tintColor = iconImage?.preferredColor {
					imageView.contentTintColor = NSColor(cgColor: tintColor)
				}

				if NSApplication.shared.effectiveAppearance.isDarkMode {
					if self.iconImage?.isDark ?? false {
						self.isDiscernable = false
					} else {
						self.isDiscernable = true
					}
				} else {
					if self.iconImage?.isBright ?? false {
						self.isDiscernable = false
					} else {
						self.isDiscernable = true
					}
				}

				needsDisplay = true
				needsLayout = true
			}
		}
	}

	private var isDiscernable = true

	override var isFlipped: Bool {
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
		imageView.setFrame(ifNotEqualTo: rectForImageView())
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
		if imageSize.height == imageSize.width {
			if imageSize.height >= viewSize.height * 0.75 {
				// Close enough to viewSize to scale up the image.
				return NSRect(x: 0.0, y: 0.0, width: viewSize.width, height: viewSize.height)
			}
			let offset = floor((viewSize.height - imageSize.height) / 2.0)
			return NSRect(x: offset, y: offset, width: imageSize.width, height: imageSize.height)
		} else if imageSize.height > imageSize.width {
			let factor = viewSize.height / imageSize.height
			let width = imageSize.width * factor
			let originX = floor((viewSize.width - width) / 2.0)
			return NSRect(x: originX, y: 0.0, width: width, height: viewSize.height)
		}

		// Wider than tall: imageSize.width > imageSize.height
		let factor = viewSize.width / imageSize.width
		let height = imageSize.height * factor
		let originY = floor((viewSize.height - height) / 2.0)
		return NSRect(x: 0.0, y: originY, width: viewSize.width, height: height)
	}
}
