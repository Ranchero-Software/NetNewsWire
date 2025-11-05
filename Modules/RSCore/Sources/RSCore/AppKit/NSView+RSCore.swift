//
//  NSView+Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 11/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

extension NSView {

    public func asImage() -> NSImage {
		let rep = bitmapImageRepForCachingDisplay(in: bounds)!
		cacheDisplay(in: bounds, to: rep)

		let img = NSImage(size: bounds.size)
		img.addRepresentation(rep)
		return img
    }

}

public extension NSView {

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

	///	A boolean indicating whether the view is or is descended from the first responder.
	var isOrIsDescendedFromFirstResponder: Bool {
		guard let firstResponder = self.window?.firstResponder as? NSView else {
			return false
		}

		return self.isDescendant(of: firstResponder)
	}

	/// A boolean indicating whether the view should draw as active.
	var shouldDrawAsActive: Bool {
		return (self.window?.isMainWindow ?? false) && self.isOrIsDescendedFromFirstResponder
	}

	/// Vertically centers a rectangle in the view's bounds.
	/// - Parameter rect: The rectangle to center.
	/// - Returns: A new rectangle, vertically centered in the view's bounds.
	func verticallyCenteredRect(_ rect: NSRect) -> NSRect {
		return rect.centeredVertically(in: self.bounds)
	}

	/// Horizontally centers a rectangle in the view's bounds.
	/// - Parameter rect: The rectangle to center.
	/// - Returns: A new rectangle, horizontally centered in the view's bounds.
	func horizontallyCenteredRect(_ rect: NSRect) -> NSRect {
		return rect.centeredHorizontally(in: self.bounds)
	}

	/// Centers a rectangle in the view's bounds.
	/// - Parameter rect: The rectangle to center.
	/// - Returns: A new rectangle, both horizontally and vertically centered in the view's bounds.
	func centeredRect(_ rect: NSRect) -> NSRect {
		return rect.centered(in: self.bounds)
	}

	/// The view's enclosing table view, if any.
	var enclosingTableView: NSTableView? {
		var nomad = self.superview

		while nomad != nil {
			if let nomad = nomad as? NSTableView {
				return nomad
			}

			nomad = nomad!.superview
		}

		return nil
	}

}
#endif
