//
//  ThumbnailView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/25/26.
//

import AppKit

/// An article’s thumbnail in a timeline cell.
///
/// The whole image shows, scaled to fit. The cell sizes the view to the image, so the corner radius rounds the image itself.
/// A placeholder color shows until the image arrives.
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
		layer?.contents = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
		// Resolved here so the placeholder follows light and dark mode.
		layer?.backgroundColor = image == nil ? Assets.Colors.thumbnailPlaceholder.cgColor : nil
	}
}

private extension ThumbnailView {

	func commonInit() {
		wantsLayer = true
		layerContentsRedrawPolicy = .onSetNeedsDisplay
		layer?.contentsGravity = .resizeAspect
		layer?.masksToBounds = true
	}
}
