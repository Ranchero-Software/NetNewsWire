//
//  SidebarCellAppearance.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

struct SidebarCellAppearance: Equatable {

	let imageSize: CGSize
	let imageMarginRight: CGFloat = 4.0
	let unreadCountMarginLeft: CGFloat = 10.0
	let textFieldFontSize: CGFloat
	let textFieldFont: NSFont

	init(rowSizeStyle: NSTableView.RowSizeStyle) {
		switch rowSizeStyle {
		case .small:
			imageSize = CGSize(width: 16, height: 16)
			textFieldFontSize = 11
		case .large:
			imageSize = CGSize(width: 22, height: 22)
			if #available(macOS 11.0, *) {
				textFieldFontSize = 15
			} else {
				textFieldFontSize = 13
			}
		default:
			imageSize = CGSize(width: 19, height: 19)
			textFieldFontSize = 13
		}
		
		self.textFieldFont = NSFont.systemFont(ofSize: textFieldFontSize)
	}
}

