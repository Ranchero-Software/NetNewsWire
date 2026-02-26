//
//  UnreadCountView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/22/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

final class UnreadCountView: NSView {
	@MainActor struct Appearance {
		static let padding = NSEdgeInsets(top: 1.0, left: 7.0, bottom: 1.0, right: 7.0)
		static let cornerRadius: CGFloat = 8.0
		static let backgroundColor = NSColor.clear
		static let textSize: CGFloat = 13.0
		static let textFont = NSFont.monospacedDigitSystemFont(ofSize: textSize, weight: NSFont.Weight.regular)
	}

	var unreadCount = 0 {
		didSet {
			invalidateIntrinsicContentSize()
			needsDisplay = true
		}
	}
	var unreadCountString: String {
		return unreadCount < 1 ? "" : "\(unreadCount.formatted())"
	}

	var isSelected: Bool = false {
		didSet {
			needsDisplay = true
		}
	}

	private var currentTextColor: NSColor {
		return isSelected ? NSColor.white : NSColor.secondaryLabelColor
	}

	private var textAttributes: [NSAttributedString.Key: AnyObject] {
		return [
			.foregroundColor: currentTextColor,
			.font: Appearance.textFont,
			.kern: NSNull()
		]
	}

	private var intrinsicContentSizeIsValid = false
	private var _intrinsicContentSize = NSSize.zero

	override var intrinsicContentSize: NSSize {
		if !intrinsicContentSizeIsValid {
			var size = NSSize.zero
			if unreadCount > 0 {
				size = textSize()
				size.width += (Appearance.padding.left + Appearance.padding.right)
				size.height += (Appearance.padding.top + Appearance.padding.bottom)
			}
			_intrinsicContentSize = size
			intrinsicContentSizeIsValid = true
		}
		return _intrinsicContentSize
	}

	override var isFlipped: Bool {
		return true
	}

	override func invalidateIntrinsicContentSize() {
		intrinsicContentSizeIsValid = false
	}

	private static var textSizeCache = [Int: NSSize]()

	private func textSize() -> NSSize {
		if unreadCount < 1 {
			return NSSize.zero
		}

		if let cachedSize = UnreadCountView.textSizeCache[unreadCount] {
			return cachedSize
		}

		var size = unreadCountString.size(withAttributes: textAttributes)
		size.height = ceil(size.height)
		size.width = ceil(size.width)

		UnreadCountView.textSizeCache[unreadCount] = size
		return size
	}

	private func textRect() -> NSRect {
		let size = textSize()
		var r = NSRect.zero
		r.size = size
		r.origin.x = (bounds.maxX - Appearance.padding.right) - r.size.width
		r.origin.y = Appearance.padding.top
		return r
	}

	override func draw(_ dirtyRect: NSRect) {
		let path = NSBezierPath(roundedRect: bounds, xRadius: Appearance.cornerRadius, yRadius: Appearance.cornerRadius)
		Appearance.backgroundColor.setFill()
		path.fill()

		if unreadCount > 0 {
			unreadCountString.draw(at: textRect().origin, withAttributes: textAttributes)
		}
	}
}
