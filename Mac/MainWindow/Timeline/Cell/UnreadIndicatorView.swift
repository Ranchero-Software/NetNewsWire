//
//  UnreadIndicatorView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/16/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class UnreadIndicatorView: NSView {

	static let unreadCircleDimension: CGFloat = 8.0
	
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

	static let bezierPath: NSBezierPath = {
		let r = NSRect(x: 0.0, y: 0.0, width: unreadCircleDimension, height: unreadCircleDimension)
		return NSBezierPath(ovalIn: r)
	}()

    override func draw(_ dirtyRect: NSRect) {
		if isSelected && isEmphasized {
			NSColor.white.setFill()
		} else {
			NSColor.controlAccentColor.setFill()
		}
		UnreadIndicatorView.bezierPath.fill()
    }
    
}
