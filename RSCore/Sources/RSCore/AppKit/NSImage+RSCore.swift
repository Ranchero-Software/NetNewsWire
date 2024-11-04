//
//  NSImage+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSImage {

	func tinted(with color: NSColor) -> NSImage {

		let image = self.copy() as! NSImage

		image.lockFocus()

		color.set()
		let rect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
		rect.fill(using: .sourceAtop)

		image.unlockFocus()

		image.isTemplate = false
		return image
	}
}
#endif
