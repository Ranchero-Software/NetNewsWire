//
//  ThumbnailView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/25/26.
//

import AppKit

/// An article’s thumbnail in a timeline cell.
///
/// By default the image is cropped to fill the view. Tall images keep their top,
/// where faces usually are. Wide images crop both sides equally.
/// With `fitsImage`, the whole image shows, on the placeholder fill.
///
/// Shows a placeholder fill until the image arrives.
final class ThumbnailView: NSView {

	var image: NSImage? {
		didSet {
			if image !== oldValue {
				needsDisplay = true
			}
		}
	}

	var fitsImage = false {
		didSet {
			if fitsImage != oldValue {
				layer?.contentsGravity = fitsImage ? .resizeAspect : .resizeAspectFill
				needsDisplay = true
			}
		}
	}

	var fillColor = NSColor.systemFill {
		didSet {
			if fillColor != oldValue {
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

	override func setFrameSize(_ newSize: NSSize) {
		let oldSize = frame.size
		super.setFrameSize(newSize)
		if newSize != oldSize {
			needsDisplay = true
		}
	}

	override func updateLayer() {
		guard let layer else {
			return
		}
		layer.contents = fitsImage ? cgImage() : croppedImage()
		// Resolved here so the placeholder follows light and dark mode.
		layer.backgroundColor = image == nil || fitsImage ? fillColor.cgColor : nil
	}
}

private extension ThumbnailView {

	func commonInit() {
		wantsLayer = true
		layerContentsRedrawPolicy = .onSetNeedsDisplay
		layer?.contentsGravity = .resizeAspectFill
		layer?.masksToBounds = true
	}

	func cgImage() -> CGImage? {
		image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
	}

	/// The image cropped to the view’s aspect ratio. Uses `CGImage` coordinates, where the origin is the top left.
	func croppedImage() -> CGImage? {
		guard let cgImage = cgImage() else {
			return nil
		}
		guard bounds.width > 0.0, bounds.height > 0.0 else {
			return cgImage
		}

		let imageWidth = CGFloat(cgImage.width)
		let imageHeight = CGFloat(cgImage.height)
		let viewAspectRatio = bounds.width / bounds.height

		let cropRect: CGRect
		if imageWidth / imageHeight > viewAspectRatio {
			let croppedWidth = floor(imageHeight * viewAspectRatio)
			cropRect = CGRect(x: floor((imageWidth - croppedWidth) / 2.0), y: 0.0, width: croppedWidth, height: imageHeight)
		} else {
			let croppedHeight = floor(imageWidth / viewAspectRatio)
			cropRect = CGRect(x: 0.0, y: 0.0, width: imageWidth, height: croppedHeight)
		}
		return cgImage.cropping(to: cropRect) ?? cgImage
	}
}
