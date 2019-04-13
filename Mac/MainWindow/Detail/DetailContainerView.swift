//
//  DetailContainerView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class DetailContainerView: NSView {

	@IBOutlet var detailStatusBarView: DetailStatusBarView!

	override var isOpaque: Bool {
		return true
	}

	var contentViewConstraints: [NSLayoutConstraint]?

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
				addSubview(contentView, positioned: .below, relativeTo: detailStatusBarView)
				let constraints = constraintsToMakeSubViewFullSize(contentView)
				NSLayoutConstraint.activate(constraints)
				contentViewConstraints = constraints
			}
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		NSColor.textBackgroundColor.setFill()
		dirtyRect.fill()
	}
}
