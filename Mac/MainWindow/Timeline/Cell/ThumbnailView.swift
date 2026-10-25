//
//  ThumbnailView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/25/26.
//

import AppKit

/// An article’s thumbnail in a timeline cell, cropped to fill the view.
/// Shows a placeholder fill until the image arrives.
final class ThumbnailView: NSView {

	var image: NSImage? {
		didSet {
			if image !== oldValue {
				needsDisplay = true
			}
		}
	}

	var cornerRadius: CGFloat = 0 {
		didSet {
			layer?.cornerRadius = cornerRadius
		}
	}

	nonisolated override var isFlipped: Bool {
		true
	}

	override var wantsUpdateLayer: Bool {
		true
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

	override func updateLayer() {
		guard let layer else {
			return
		}
		layer.contents = image
		// Resolved here so the placeholder follows light and dark mode.
		layer.backgroundColor = image == nil ? NSColor.quaternarySystemFill.cgColor : nil
	}
}

private extension ThumbnailView {

	func commonInit() {
		wantsLayer = true
		layerContentsRedrawPolicy = .onSetNeedsDisplay
		layer?.contentsGravity = .resizeAspectFill
		layer?.masksToBounds = true
	}
}
