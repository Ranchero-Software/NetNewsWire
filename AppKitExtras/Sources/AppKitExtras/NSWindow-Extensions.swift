//
//  NSWindow-Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 10/10/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSWindow {

	var isDisplayingSheet: Bool {

		return attachedSheet != nil
	}

	func makeFirstResponderUnlessDescendantIsFirstResponder(_ responder: NSResponder) {

		if let fr = firstResponder, fr.hasAncestor(responder) {
			return
		}
		makeFirstResponder(responder)
	}

	func setPointAndSizeAdjustingForScreen(point: NSPoint, size: NSSize, minimumSize: NSSize) {

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

	var flippedOrigin: NSPoint? {

		// Screen coordinates start at lower-left.
		// With this we can use upper-left, like sane people.

		get {
			guard let screenFrame = screen?.frame else {
				return nil
			}

			let flippedPoint = NSPoint(x: frame.origin.x, y: screenFrame.maxY - frame.maxY)
			return flippedPoint
		}
		set {
			guard let screenFrame = screen?.frame else {
				return
			}
			var point = newValue!
			point.y = screenFrame.maxY - point.y
			setFrameTopLeftPoint(point)
		}
	}

	func setFlippedOriginAdjustingForScreen(_ point: NSPoint) {

		guard let screenFrame = screen?.frame else {
			return
		}

		let paddingFromEdge: CGFloat = 8.0
		var unflippedPoint = point
		unflippedPoint.y = (screenFrame.maxY - point.y) - frame.height
		if unflippedPoint.y < 0 {
			unflippedPoint.y = paddingFromEdge
		}
		if unflippedPoint.x < 0 {
			unflippedPoint.x = paddingFromEdge
		}
		setFrameOrigin(unflippedPoint)
	}
}
#endif
