//
//  MasterTableViewCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

struct MasterTableViewCellLayout {

	private static let imageSize = CGSize(width: 16, height: 16)
	private static let imageMarginLeft = CGFloat(integerLiteral: 8)
	private static let imageMarginRight = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginLeft = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginRight = CGFloat(integerLiteral: 8)

	let faviconRect: CGRect
	let titleRect: CGRect
	let unreadCountRect: CGRect
	
	init(cellSize: CGSize, shouldShowImage: Bool, label: UILabel, unreadCountView: MasterUnreadCountView) {

		let bounds = CGRect(x: 0.0, y: 0.0, width: floor(cellSize.width), height: floor(cellSize.height))

		var rFavicon = CGRect.zero
		if shouldShowImage {
			rFavicon = CGRect(x: MasterTableViewCellLayout.imageMarginLeft, y: 0.0, width: MasterTableViewCellLayout.imageSize.width, height: MasterTableViewCellLayout.imageSize.height)
			rFavicon = MasterTableViewCellLayout.centerVertically(rFavicon, bounds)
		}
		self.faviconRect = rFavicon

		let labelSize = SingleLineUILabelSizer.size(for: label.text ?? "", font: label.font!)

		var rLabel = CGRect(x: 0.0, y: 0.0, width: labelSize.width, height: labelSize.height)
		if shouldShowImage {
			rLabel.origin.x = rFavicon.maxX + MasterTableViewCellLayout.imageMarginRight
		}
		rLabel = MasterTableViewCellLayout.centerVertically(rLabel, bounds)

		let unreadCountSize = unreadCountView.intrinsicContentSize
		let unreadCountIsHidden = unreadCountView.unreadCount < 1

		var rUnread = CGRect.zero
		if !unreadCountIsHidden {
			rUnread.size = unreadCountSize
			rUnread.origin.x = (bounds.maxX - unreadCountSize.width) - MasterTableViewCellLayout.unreadCountMarginRight
			rUnread = MasterTableViewCellLayout.centerVertically(rUnread, bounds)
			let labelMaxX = rUnread.minX - MasterTableViewCellLayout.unreadCountMarginLeft
			if rLabel.maxX > labelMaxX {
				rLabel.size.width = labelMaxX - rLabel.minX
			}
		}
		self.unreadCountRect = rUnread

		if rLabel.maxX > bounds.maxX {
			rLabel.size.width = bounds.maxX - rLabel.maxX
		}
		
		self.titleRect = rLabel
	}
	
	// Ideally this will be implemented in RSCore (see RSGeometry)
	static func centerVertically(_ originalRect: CGRect, _ containerRect: CGRect) -> CGRect {
		var result = originalRect
		result.origin.y = containerRect.midY - (result.height / 2.0)
		result = result.integral
		result.size = originalRect.size
		return result
	}
	
}
