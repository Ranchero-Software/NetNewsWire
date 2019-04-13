//
//  AccountsTableViewBackgroundView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/19/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class AccountsTableViewBackgroundView: NSView {

	let lightBorderColor = NSColor(white: 0.71, alpha: 1.0)
	let darkBorderColor = NSColor(red: 0.41, green: 0.43, blue: 0.44, alpha: 1.0)

	override func draw(_ dirtyRect: NSRect) {
		let color = self.effectiveAppearance.isDarkMode ? darkBorderColor : lightBorderColor
		color.setFill()
		dirtyRect.fill()
	}
}
