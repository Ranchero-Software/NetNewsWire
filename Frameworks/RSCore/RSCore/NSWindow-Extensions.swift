//
//  NSWindow-Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 10/10/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

public extension NSWindow {
	
	public func makeFirstResponderUnlessDescendantIsFirstResponder(_ responder: NSResponder) {

		if let fr = firstResponder, fr.hasAncestor(responder) {
			return
		}
		makeFirstResponder(responder)
	}

	public func setPointAndSizeAdjustingForScreen(point: NSPoint, size: NSSize, minimumSize: NSSize) {

		// point.y specifices from the *top* of the screen, even though screen coordinates work from the bottom up. This is for convenience.
		// The eventual size may be smaller than requested, since the screen may be small, but not smaller than minimumSize.

		guard let screenFrame = screen?.visibleFrame else {
			return
		}

		let paddingFromScreenEdge: CGFloat = 8.0
		let x = point.x
		let y = screenFrame.maxY - point.y

		var width = size.width
		var height = size.height

		if x + width > screenFrame.maxX {
			width = max((screenFrame.maxX - x) - paddingFromScreenEdge, minimumSize.width)
		}
		if y - height < 0.0 {
			height = max((screenFrame.maxY - point.y) - paddingFromScreenEdge, minimumSize.height)
		}

		let frame = NSRect(x: x, y: y, width: width, height: height)
		setFrame(frame, display: true)
		setFrameTopLeftPoint(frame.origin)
	}
}
