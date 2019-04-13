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

	private let lightModeFillColor = NSColor(white: 0.97, alpha: 1.0)
	private let darkModeFillColor = NSColor(red: 0.32, green: 0.34, blue: 0.35, alpha: 1.0)

	private let lightModeBorderColor = NSColor(white: 0.71, alpha: 1.0)
	private let darkModeBorderColor = NSColor(red: 0.41, green: 0.43, blue: 0.44, alpha: 1.0)

	override var isFlipped: Bool {
		return true
	}

	override var isOpaque: Bool {
		return true
	}

	override func draw(_ dirtyRect: NSRect) {
		let fillColor = self.effectiveAppearance.isDarkMode ? darkModeFillColor : lightModeFillColor
		fillColor.setFill()
		dirtyRect.fill()

		let borderColor = self.effectiveAppearance.isDarkMode ? darkModeBorderColor : lightModeBorderColor
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
