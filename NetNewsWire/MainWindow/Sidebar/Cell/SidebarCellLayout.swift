//
//  SidebarLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

// image - title - unreadCount

struct SidebarCellLayout {

	let faviconRect: CGRect
	let titleRect: CGRect
	let unreadCountRect: CGRect
	
	init(appearance: SidebarCellAppearance, cellSize: NSSize, shouldShowImage: Bool, textField: NSTextField, unreadCountView: UnreadCountView) {

		let bounds = NSRect(x: 0.0, y: 0.0, width: floor(cellSize.width), height: floor(cellSize.height))

		var rFavicon = NSRect.zero
		if shouldShowImage {
			rFavicon = NSRect(x: 0.0, y: 0.0, width: appearance.imageSize.width, height: appearance.imageSize.height)
			rFavicon = RSRectCenteredVerticallyInRect(rFavicon, bounds)
		}
		self.faviconRect = rFavicon

//		textField.sizeToFit()
//		let textFieldSize = textField.fittingSize//frame.size
		let textFieldSize = SingleLineTextFieldSizer.size(for: textField.stringValue, font: textField.font!)

		var rTextField = NSRect(x: 0.0, y: 0.0, width: textFieldSize.width, height: textFieldSize.height)
		if shouldShowImage {
			rTextField.origin.x = NSMaxX(rFavicon) + appearance.imageMarginRight
		}
		rTextField = RSRectCenteredVerticallyInRect(rTextField, bounds)

		let unreadCountSize = unreadCountView.intrinsicContentSize
		let unreadCountIsHidden = unreadCountView.unreadCount < 1

		var rUnread = NSRect.zero
		if !unreadCountIsHidden {
			rUnread.size = unreadCountSize
			rUnread.origin.x = NSMaxX(bounds) - unreadCountSize.width
			rUnread = RSRectCenteredVerticallyInRect(rUnread, bounds)
			let textFieldMaxX = NSMinX(rUnread) - appearance.unreadCountMarginLeft
			if NSMaxX(rTextField) > textFieldMaxX {
				rTextField.size.width = textFieldMaxX - NSMinX(rTextField)
			}
		}
		self.unreadCountRect = rUnread

		if NSMaxX(rTextField) > NSMaxX(bounds) {
			rTextField.size.width = NSMaxX(bounds) - NSMinX(rTextField)
		}
		self.titleRect = rTextField
	}
}
