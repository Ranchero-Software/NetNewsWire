//
//  DetailContainerView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class DetailContainerView: NSView, @MainActor NSTextFinderBarContainer {

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
				// Add the content view below the find bar container so the find bar floats over it
				addSubview(contentView, positioned: .below, relativeTo: findBarContainerView)

				// Constrain the content view to fill the entire container
				var constraints = constraintsToMakeSubViewFullSize(contentView)

				// Constrain the find bar container to the safe area top (below the toolbar)
				constraints.append(findBarContainerView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor))
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

	// MARK: NSTextFinderBarContainer

	@IBOutlet var findBarContainerView: NSView!
	@IBOutlet var findBarHeightConstraint: NSLayoutConstraint!


	public var findBarView: NSView? = nil {
		didSet {
			oldValue?.removeFromSuperview()
		}
	}

	public var isFindBarVisible = false {
		didSet {
			// It seems AppKit assumes the findBarView will be removed from its superview when it's
			// not being shown, so we have to fulfill that expectation in addition to hiding the stack view
			// container we embed it in.
			if
				self.isFindBarVisible,
				let view = findBarView
			{
				view.layoutSubtreeIfNeeded()
				view.frame.origin = NSZeroPoint
				view.frame.size.width = self.findBarContainerView.bounds.width
				findBarContainerView.frame = view.bounds
				findBarHeightConstraint.constant = view.frame.size.height + 1.0
				findBarContainerView.addSubview(view)
			}
			else {
				if let view = findBarView {
					view.removeFromSuperview()
					findBarHeightConstraint.constant = 0
				}
			}

			// Notify the web view so it can update its obscuredContentInsets
			if let webView = contentView as? DetailWebView {
				webView.findBarHeight = isFindBarVisible ? findBarHeightConstraint.constant : 0
			}
		}
	}

	func findBarViewDidChangeHeight() {
		if let height = findBarView?.frame.size.height {
			findBarHeightConstraint.constant = height + 1.0
			findBarContainerView.layoutSubtreeIfNeeded()
			findBarView?.setFrameOrigin(NSPoint.zero)

			// Notify the web view about the updated find bar height
			if isFindBarVisible, let webView = contentView as? DetailWebView {
				webView.findBarHeight = findBarHeightConstraint.constant
			}
		}
	}

}
