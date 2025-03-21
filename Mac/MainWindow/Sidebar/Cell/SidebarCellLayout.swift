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
			rFavicon = rFavicon.centeredVertically(in: bounds)
		}
		self.faviconRect = rFavicon

		let textFieldSize = SingleLineTextFieldSizer.size(for: textField.stringValue, font: textField.font!)

		var rTextField = NSRect(x: 0.0, y: 0.0, width: textFieldSize.width, height: textFieldSize.height)
		if shouldShowImage {
			rTextField.origin.x = rFavicon.maxX + appearance.imageMarginRight
		}
		rTextField = rTextField.centeredVertically(in: bounds)

		let unreadCountSize = unreadCountView.intrinsicContentSize
		let unreadCountIsHidden = unreadCountView.unreadCount < 1

		var rUnread = NSRect.zero
		if !unreadCountIsHidden {
			rUnread.size = unreadCountSize
			rUnread.origin.x = bounds.maxX - unreadCountSize.width
			rUnread = rUnread.centeredVertically(in: bounds)
			let textFieldMaxX = rUnread.minX - appearance.unreadCountMarginLeft
			if rTextField.maxX > textFieldMaxX {
				rTextField.size.width = textFieldMaxX - rTextField.minX
			}
		}
		self.unreadCountRect = rUnread

		if rTextField.maxX > bounds.maxX {
			rTextField.size.width = bounds.maxX - rTextField.minX
		}
		self.titleRect = rTextField
	}
}
