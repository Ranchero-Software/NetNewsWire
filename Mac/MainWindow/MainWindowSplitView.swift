//
//  MainWindowSplitView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/7/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

/// The main window’s split views. In light mode, the dividers are a little darker than the system’s.
class MainWindowSplitView: NSSplitView {

	private static let lightDividerColor = NSColor(srgbRed: 200 / 255, green: 200 / 255, blue: 200 / 255, alpha: 1)

	override var dividerColor: NSColor {
		if effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
			return super.dividerColor
		}
		return Self.lightDividerColor
	}
}
