//
//  AccountsControlsBackgroundView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

final class AccountsControlsBackgroundView: NSView {

	private static let lightModeFillColor = NSColor(white: 0.97, alpha: 1.0)
	private static let darkModeFillColor = NSColor(white: 0.24, alpha: 1.0)

	private static let lightModeBorderColor = NSColor(white: 0.71, alpha: 1.0)
	private static let darkModeBorderColor = NSColor(white: 0.5, alpha: 1.0)

	override var isFlipped: Bool {
		return true
	}

	override var isOpaque: Bool {
		return true
	}

	override func draw(_ dirtyRect: NSRect) {
		let fillColor = self.effectiveAppearance.isDarkMode ? AccountsControlsBackgroundView.darkModeFillColor : AccountsControlsBackgroundView.lightModeFillColor
		fillColor.setFill()
		dirtyRect.fill()

		let borderColor = self.effectiveAppearance.isDarkMode ? AccountsControlsBackgroundView.darkModeBorderColor : AccountsControlsBackgroundView.lightModeBorderColor
		borderColor.set()

		let topPath = NSBezierPath()
		topPath.lineWidth = 1.0
		topPath.move(to: NSPoint(x: 0.0, y: 0.5))
		topPath.line(to: NSPoint(x: bounds.maxX + 0.0, y: 0.5))
		topPath.stroke()

		let rightPath = NSBezierPath()
		rightPath.lineWidth = 1.0
		rightPath.move(to: NSPoint(x: bounds.maxX - 0.5, y: 1))
		rightPath.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
		rightPath.stroke()

		let bottomPath = NSBezierPath()
		bottomPath.lineWidth = 1.0
		bottomPath.move(to: NSPoint(x: 0.0, y: bounds.maxY - 0.5))
		bottomPath.line(to: NSPoint(x: bounds.maxX - 1.0, y: bounds.maxY - 0.5))
		bottomPath.stroke()
	}
}
