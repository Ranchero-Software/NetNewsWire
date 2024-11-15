//
//  FeedTableViewSectionHeaderLayout.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

struct FeedTableViewSectionHeaderLayout {

	private static let labelMarginRight = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginRight = CGFloat(integerLiteral: 16)
	private static let disclosureButtonSize = CGSize(width: 44, height: 44)
	private static let verticalPadding = CGFloat(integerLiteral: 11)

	private static let minRowHeight = CGFloat(integerLiteral: 44)
	
	let titleRect: CGRect
	let unreadCountRect: CGRect
	let disclosureButtonRect: CGRect
	
	let height: CGFloat
	
	init(cellWidth: CGFloat, insets: UIEdgeInsets, label: UILabel, unreadCountView: FeedUnreadCountView) {

		let bounds = CGRect(x: insets.left, y: 0.0, width: floor(cellWidth - insets.right), height: 0.0)
		
		// Disclosure Button
		var rDisclosure = CGRect.zero
		rDisclosure.size = FeedTableViewSectionHeaderLayout.disclosureButtonSize
		rDisclosure.origin.x = bounds.origin.x

		// Unread Count
		let unreadCountSize = unreadCountView.contentSize
		let unreadCountIsHidden = unreadCountView.unreadCount < 1

		var rUnread = CGRect.zero
		if !unreadCountIsHidden {
			rUnread.size = unreadCountSize
			rUnread.origin.x = bounds.maxX - (FeedTableViewSectionHeaderLayout.unreadCountMarginRight + unreadCountSize.width)
		}
		
		// Max Unread Count
		// We can't reload Section Headers so we don't let the title extend into the (probably) worse case Unread Count area.
		let maxUnreadCountView = FeedUnreadCountView(frame: CGRect.zero)
		maxUnreadCountView.unreadCount = 888
		let maxUnreadCountSize = maxUnreadCountView.contentSize

		// Title
		let rLabelx = insets.left + FeedTableViewSectionHeaderLayout.disclosureButtonSize.width
		let rLabely = UIFontMetrics.default.scaledValue(for: FeedTableViewSectionHeaderLayout.verticalPadding)
		
		var labelWidth = CGFloat.zero
		labelWidth = cellWidth - (rLabelx + FeedTableViewSectionHeaderLayout.labelMarginRight + maxUnreadCountSize.width + FeedTableViewSectionHeaderLayout.unreadCountMarginRight)
		
		let labelSizeInfo = MultilineUILabelSizer.size(for: label.text ?? "", font: label.font, numberOfLines: 0, width: Int(floor(labelWidth)))
		var rLabel = CGRect(x: rLabelx, y: rLabely, width: labelWidth, height: labelSizeInfo.size.height)
		
		// Determine cell height
		let paddedLabelHeight = rLabel.maxY + UIFontMetrics.default.scaledValue(for: FeedTableViewSectionHeaderLayout.verticalPadding)
		let maxGraphicsHeight = [rUnread, rDisclosure].maxY()
		var cellHeight = max(paddedLabelHeight, maxGraphicsHeight)
		if cellHeight < FeedTableViewSectionHeaderLayout.minRowHeight {
			cellHeight = FeedTableViewSectionHeaderLayout.minRowHeight
		}
		
		// Center in Cell
		let newBounds = CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: cellHeight)
		if !unreadCountIsHidden {
			rUnread = FeedTableViewCellLayout.centerVertically(rUnread, newBounds)
		}
		rDisclosure = FeedTableViewCellLayout.centerVertically(rDisclosure, newBounds)

		// Small fonts need centered if we hit the minimum row height
		if cellHeight == FeedTableViewSectionHeaderLayout.minRowHeight {
			rLabel = FeedTableViewCellLayout.centerVertically(rLabel, newBounds)
		}
		
		//  Assign the properties
		self.height = cellHeight
		self.unreadCountRect = rUnread
		self.disclosureButtonRect = rDisclosure
		self.titleRect = rLabel
		
	}
	
}
