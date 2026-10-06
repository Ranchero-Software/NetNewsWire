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
				// Leading and trailing follow the safe area so the article view doesn’t extend under the sidebar
				// in column layout on macOS 26. Top stays at the edge: the web view handles the toolbar itself.
				let constraints = [
					contentView.topAnchor.constraint(equalTo: topAnchor),
					contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
					contentView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
					contentView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor)
				]
				NSLayoutConstraint.activate(constraints)
				contentViewConstraints = constraints
			}
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		NSColor.controlBackgroundColor.set()
		let r = dirtyRect.intersection(bounds)
		r.fill()
	}
}
