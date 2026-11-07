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

	private static let smallFontSize: CGFloat = 11
	private static let mediumFontSize: CGFloat = 13
	private static let largeFontSize: CGFloat = 15
	private static let extraLargeFontSize: CGFloat = 17
	private static let extraExtraLargeFontSize: CGFloat = 20

	private static let smallImageSize = CGSize(width: 16, height: 16)
	private static let mediumImageSize = CGSize(width: 19, height: 19)
	private static let largeImageSize = CGSize(width: 22, height: 22)
	private static let extraLargeImageSize = CGSize(width: 25, height: 25)
	private static let extraExtraLargeImageSize = CGSize(width: 28, height: 28)

	/// `systemRowSizeStyle` is used only when `textSize` is `.system`.
	init(textSize: SidebarTextSize, systemRowSizeStyle: NSTableView.RowSizeStyle) {
		switch textSize {
		case .system:
			switch systemRowSizeStyle {
			case .small:
				imageSize = Self.smallImageSize
				textFieldFontSize = Self.smallFontSize
			case .large:
				imageSize = Self.largeImageSize
				textFieldFontSize = Self.largeFontSize
			default:
				imageSize = Self.mediumImageSize
				textFieldFontSize = Self.mediumFontSize
			}
		case .small:
			imageSize = Self.smallImageSize
			textFieldFontSize = Self.smallFontSize
		case .medium:
			imageSize = Self.mediumImageSize
			textFieldFontSize = Self.mediumFontSize
		case .large:
			imageSize = Self.largeImageSize
			textFieldFontSize = Self.largeFontSize
		case .extraLarge:
			imageSize = Self.extraLargeImageSize
			textFieldFontSize = Self.extraLargeFontSize
		case .extraExtraLarge:
			imageSize = Self.extraExtraLargeImageSize
			textFieldFontSize = Self.extraExtraLargeFontSize
		}

		self.textFieldFont = NSFont.systemFont(ofSize: textFieldFontSize)
	}
}
