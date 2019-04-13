//
//  NSView-Extensions.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/13/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

extension NSView {

	func constraintsToMakeSubViewFullSize(_ subview: NSView) -> [NSLayoutConstraint] {
		let leadingConstraint = NSLayoutConstraint(item: subview, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0)
		let trailingConstraint = NSLayoutConstraint(item: subview, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0)
		let topConstraint = NSLayoutConstraint(item: subview, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0)
		let bottomConstraint = NSLayoutConstraint(item: subview, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0)
		return [leadingConstraint, trailingConstraint, topConstraint, bottomConstraint]
	}
}
