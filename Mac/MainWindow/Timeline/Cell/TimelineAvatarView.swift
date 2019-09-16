//
//  TimelineAvatarView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class TimelineAvatarView: NSView {

	var image: NSImage? = nil {
		didSet {
			imageView.image = image
			updateHasExposedBackground()
			needsDisplay = true
			needsLayout = true
		}
	}

	override var isFlipped: Bool {
		return true
	}

	private let imageView: NSImageView = {
		let imageView = NSImageView(frame: NSRect.zero)
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		imageView.imageScaling = .scaleProportionallyDown
		return imageView
	}()

	private var hasExposedBackground = true {
		didSet {
			if oldValue != hasExposedBackground {
				needsDisplay = true
			}
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

	convenience init() {
		self.init(frame: NSRect.zero)
	}

	override func viewDidMoveToSuperview() {
		needsLayout = true
		needsDisplay = true
	}

	override func layout() {
		resizeSubviews(withOldSize: NSZeroSize)
	}

	override func resizeSubviews(withOldSize oldSize: NSSize) {
		imageView.rs_setFrameIfNotEqual(rectForImageView())
	}

	override func draw(_ dirtyRect: NSRect) {
		guard hasExposedBackground else {
			return
		}
		let rImage = imageView.frame
		if rImage.contains(dirtyRect) {
			return
		}

		let color = NSApplication.shared.effectiveAppearance.isDarkMode ? AppAssets.avatarDarkBackgroundColor : AppAssets.avatarLightBackgroundColor
		color.set()
		dirtyRect.fill()
	}
}

private extension TimelineAvatarView {

	func commonInit() {
		addSubview(imageView)
	}

	func rectForImageView() -> NSRect {
		guard let image = image else {
			return NSRect.zero
		}

		let imageSize = image.size
		let viewSize = bounds.size
		if imageSize.height == imageSize.width {
			return NSMakeRect(0.0, 0.0, viewSize.width, viewSize.height)
		}
		else if imageSize.height > imageSize.width {
			let factor = viewSize.height / imageSize.height
			let width = imageSize.width * factor
			let originX = floor((viewSize.width - width) / 2.0)
			return NSMakeRect(originX, 0.0, width, viewSize.height)
		}

		// Wider than tall: imageSize.width > imageSize.height
		let factor = viewSize.width / imageSize.width
		let height = imageSize.height * factor
		let originY = floor((viewSize.height - height) / 2.0)
		return NSMakeRect(0.0, originY, viewSize.width, height)
	}

	func updateHasExposedBackground() {
		let rImage = rectForImageView()
		hasExposedBackground = rImage.size.height < bounds.size.height || rImage.size.width < bounds.size.width
	}
}
