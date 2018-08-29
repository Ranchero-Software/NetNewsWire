//
//  UnreadCountView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/22/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import AppKit

private let padding = appDelegate.currentTheme.edgeInsets(forKey: "MainWindow.SourceList.unreadCount.padding")
private let cornerRadius = appDelegate.currentTheme.float(forKey: "MainWindow.SourceList.unreadCount.cornerRadius")
private let backgroundColor = appDelegate.currentTheme.colorWithAlpha(forKey: "MainWindow.SourceList.unreadCount.backgroundColor")
private let textColor = appDelegate.currentTheme.colorWithAlpha(forKey: "MainWindow.SourceList.unreadCount.color")
private let textSize = appDelegate.currentTheme.float(forKey: "MainWindow.SourceList.unreadCount.fontSize")
private let textFont = NSFont.systemFont(ofSize: textSize, weight: NSFont.Weight.semibold)
private var textAttributes: [NSAttributedStringKey: AnyObject] = [NSAttributedStringKey.foregroundColor: textColor, NSAttributedStringKey.font: textFont, NSAttributedStringKey.kern: NSNull()]
private var textSizeCache = [Int: NSSize]()

class UnreadCountView : NSView {
	
	var unreadCount = 0 {
		didSet {
			invalidateIntrinsicContentSize()
			needsDisplay = true
		}
	}
	var unreadCountString: String {
		return unreadCount < 1 ? "" : "\(unreadCount)"
	}

	private var intrinsicContentSizeIsValid = false
	private var _intrinsicContentSize = NSZeroSize
	
	override var intrinsicContentSize: NSSize {
		if !intrinsicContentSizeIsValid {
			var size = NSZeroSize
			if unreadCount > 0 {
				size = textSize()
				size.width += (padding.left + padding.right)
				size.height += (padding.top + padding.bottom)
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

	private func textSize() -> NSSize {

		if unreadCount < 1 {
			return NSZeroSize
		}

		if let cachedSize = textSizeCache[unreadCount] {
			return cachedSize
		}

		var size = unreadCountString.size(withAttributes: textAttributes)
		size.height = ceil(size.height)
		size.width = ceil(size.width)

		textSizeCache[unreadCount] = size
		return size
	}

	private func textRect() -> NSRect {

		let size = textSize()
		var r = NSZeroRect
		r.size = size
		r.origin.x = (NSMaxX(bounds) - padding.right) - r.size.width
		r.origin.y = padding.top
		return r
	}

	override func draw(_ dirtyRect: NSRect) {

		let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
		backgroundColor.setFill()
		path.fill()

		if unreadCount > 0 {
			unreadCountString.draw(at: textRect().origin, withAttributes: textAttributes)
		}
	}
	
}

