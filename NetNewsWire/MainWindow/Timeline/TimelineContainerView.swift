//
//  TimelineContainerView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/13/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class TimelineContainerView: NSView {

	private var contentViewConstraints: [NSLayoutConstraint]?

	var contentView: NSView? {
		didSet {
			if contentView == oldValue {
				return
			}

			if let currentConstraints = contentViewConstraints {
				NSLayoutConstraint.deactivate(currentConstraints)
			}
			contentViewConstraints = nil
			oldValue?.removeFromSuperviewWithoutNeedingDisplay()

			if let contentView = contentView {
				contentView.translatesAutoresizingMaskIntoConstraints = false
				addSubview(contentView)
				let constraints = constraintsToMakeSubViewFullSize(contentView)
				NSLayoutConstraint.activate(constraints)
				contentViewConstraints = constraints
			}
		}
	}

	override var isOpaque: Bool {
		return true
	}

	override func draw(_ dirtyRect: NSRect) {
		NSColor.textBackgroundColor.setFill()
		dirtyRect.fill()
	}
}

