//
//  UnreadIndicatorView.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/16/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

class UnreadIndicatorView: NSView {

	static let unreadCircleDimension = appDelegate.currentTheme.float(forKey: "MainWindow.Timeline.cell.unreadCircleDimension")
	
	static let bezierPath: NSBezierPath = {
		let r = NSRect(x: 0.0, y: 0.0, width: unreadCircleDimension, height: unreadCircleDimension)
		return NSBezierPath(ovalIn: r)
	}()
	
	static let unreadCircleColor = appDelegate.currentTheme.color(forKey: "MainWindow.Timeline.cell.unreadCircleColor")

	var isEmphasized = false {
		didSet {
			if isEmphasized != oldValue {
				needsDisplay = true
			}
		}
	}

	var isSelected = false {
		didSet {
			if isSelected != oldValue {
				needsDisplay = true
			}
		}
	}

    override func draw(_ dirtyRect: NSRect) {

		let color = isEmphasized && isSelected ? NSColor.white : UnreadIndicatorView.unreadCircleColor
		color.setFill()
		UnreadIndicatorView.bezierPath.fill()
    }
    
}
