//
//  NSView+Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 11/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit
import FoundationExtras

public extension NSView {

	func asImage() -> NSImage {
		let rep = bitmapImageRepForCachingDisplay(in: bounds)!
		cacheDisplay(in: bounds, to: rep)

		let img = NSImage(size: bounds.size)
		img.addRepresentation(rep)
		return img
	}

	func constraintsToMakeSubViewFullSize(_ subview: NSView) -> [NSLayoutConstraint] {

		let leadingConstraint = NSLayoutConstraint(item: subview, attribute: .leading, relatedBy: .equal, toItem: self.safeAreaLayoutGuide, attribute: .leading, multiplier: 1.0, constant: 0.0)
		let trailingConstraint = NSLayoutConstraint(item: subview, attribute: .trailing, relatedBy: .equal, toItem: self.safeAreaLayoutGuide, attribute: .trailing, multiplier: 1.0, constant: 0.0)
		let topConstraint = NSLayoutConstraint(item: subview, attribute: .top, relatedBy: .equal, toItem: self.safeAreaLayoutGuide, attribute: .top, multiplier: 1.0, constant: 0.0)
		let bottomConstraint = NSLayoutConstraint(item: subview, attribute: .bottom, relatedBy: .equal, toItem: self.safeAreaLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: 0.0)
		return [leadingConstraint, trailingConstraint, topConstraint, bottomConstraint]
	}

	/// Keeps a subview at same size as receiver.
	///
	/// - Parameter subview: The subview to constrain. Must be a descendant of `self`.
	func addFullSizeConstraints(forSubview subview: NSView) {
		NSLayoutConstraint.activate([
			subview.leadingAnchor.constraint(equalTo: leadingAnchor),
			subview.trailingAnchor.constraint(equalTo: trailingAnchor),
			subview.topAnchor.constraint(equalTo: topAnchor),
			subview.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	/// Sets the view's frame if it's different from the current frame.
	///
	/// - Parameter rect: The new frame.
	func setFrame(ifNotEqualTo rect: NSRect) {
		if self.frame != rect {
			self.frame = rect
		}
	}
}
#endif
