//
//  TimelineHeaderView.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/29/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

final class TimelineHeaderView: NSView {

	private var didConfigureLayer = false

	override var wantsUpdateLayer: Bool {
		return true
	}

	override func updateLayer() {

		guard !didConfigureLayer else {
			return
		}
		if let layer = layer {
			let color = appDelegate.currentTheme.color(forKey: "MainWindow.Timeline.header.backgroundColor")
			layer.backgroundColor = color.cgColor
			didConfigureLayer = true
		}
	}
}
