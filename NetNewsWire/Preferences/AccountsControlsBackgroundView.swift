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

	private static let lightGrayColor = NSColor.rs_color(withHexString: "f7f7f7")!
	private static let darkGrayColor = NSColor.rs_color(withHexString: "52565a")!

	override func draw(_ dirtyRect: NSRect) {

		let color = self.effectiveAppearance.isDarkMode ? AccountsControlsBackgroundView.darkGrayColor : AccountsControlsBackgroundView.lightGrayColor
		color.set()
		dirtyRect.fill()
	}
}
