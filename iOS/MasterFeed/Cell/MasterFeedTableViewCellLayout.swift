//
//  MasterTableViewCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

struct MasterFeedTableViewCellLayout {

	private static let editingControlIndent = CGFloat(integerLiteral: 40)
	private static let imageSize = CGSize(width: 20, height: 20)
	private static let imageMarginRight = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginLeft = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginRight = CGFloat(integerLiteral: 16)
	private static let disclosureButtonSize = CGSize(width: 44, height: 44)

	private static let minRowHeight = CGFloat(integerLiteral: 44)
	
	static let faviconCornerRadius = CGFloat(integerLiteral: 2)

	let faviconRect: CGRect
	let titleRect: CGRect
	let unreadCountRect: CGRect
	let disclosureButtonRect: CGRect
	let separatorInsets: UIEdgeInsets
	
	let height: CGFloat
	
	init(cellWidth: CGFloat, insets: UIEdgeInsets, label: UILabel, unreadCountView: MasterFeedUnreadCountView, showingEditingControl: Bool, indent: Bool, shouldShowDisclosure: Bool) {

		var initialIndent = insets.left
		if indent {
			initialIndent += MasterFeedTableViewCellLayout.imageSize.width + MasterFeedTableViewCellLayout.imageMarginRight
		}
		if showingEditingControl {
			initialIndent += MasterFeedTableViewCellLayout.editingControlIndent
		}
		
		let bounds = CGRect(x: initialIndent, y: 0.0, width: floor(cellWidth - initialIndent - insets.right), height: 0.0)
		
		// Disclosure Button
		var rDisclosure = CGRect.zero
		if shouldShowDisclosure {
			rDisclosure.size = MasterFeedTableViewCellLayout.disclosureButtonSize
			rDisclosure.origin.x = bounds.origin.x
		}

		// Favicon
		var rFavicon = CGRect.zero
		if !shouldShowDisclosure {
			let x = bounds.origin.x + ((MasterFeedTableViewCellLayout.disclosureButtonSize.width - MasterFeedTableViewCellLayout.imageSize.width) / 2)
			let y = UIFontMetrics.default.scaledValue(for: CGFloat(integerLiteral: 4))
			rFavicon = CGRect(x: x, y: y, width: MasterFeedTableViewCellLayout.imageSize.width, height: MasterFeedTableViewCellLayout.imageSize.height)
		}

		//  Separator Insets
		separatorInsets = UIEdgeInsets(top: 0, left: rFavicon.maxX + MasterFeedTableViewCellLayout.imageMarginRight, bottom: 0, right: 0)
		
		// Unread Count
		let unreadCountSize = unreadCountView.contentSize
		let unreadCountIsHidden = unreadCountView.unreadCount < 1

		var rUnread = CGRect.zero
		if !unreadCountIsHidden {
			rUnread.size = unreadCountSize
			rUnread.origin.x = bounds.maxX - (MasterFeedTableViewCellLayout.unreadCountMarginRight + unreadCountSize.width)
			if showingEditingControl {
				rUnread.origin.x = rUnread.origin.x - MasterFeedTableViewCellLayout.editingControlIndent
			}
		}
		
		// Title
		let labelWidth = bounds.width - (rFavicon.width + MasterFeedTableViewCellLayout.imageMarginRight + MasterFeedTableViewCellLayout.unreadCountMarginLeft + rUnread.width + MasterFeedTableViewCellLayout.disclosureButtonSize.width + MasterFeedTableViewCellLayout.unreadCountMarginRight)
		let labelSizeInfo = MultilineUILabelSizer.size(for: label.text ?? "", font: label.font, numberOfLines: 0, width: Int(floor(labelWidth)))
		
		let rLabelx = bounds.minX + MasterFeedTableViewCellLayout.disclosureButtonSize.width
		var rLabel = CGRect(x: rLabelx, y: 0.0, width: labelSizeInfo.size.width, height: labelSizeInfo.size.height)
		
		// Determine cell height
		var cellHeight = [rFavicon, rLabel, rUnread, rDisclosure].maxY()
		if cellHeight < MasterFeedTableViewCellLayout.minRowHeight {
			cellHeight = MasterFeedTableViewCellLayout.minRowHeight
		}
		
		// Center in Cell
		let newBounds = CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: cellHeight)

		if !shouldShowDisclosure && labelSizeInfo.numberOfLinesUsed == 1 {
			rFavicon = MasterFeedTableViewCellLayout.centerVertically(rFavicon, newBounds)
		}
		
		if !unreadCountIsHidden {
			rUnread = MasterFeedTableViewCellLayout.centerVertically(rUnread, newBounds)
		}

		if shouldShowDisclosure {
			rDisclosure = MasterFeedTableViewCellLayout.centerVertically(rDisclosure, newBounds)
		}

		rLabel = MasterFeedTableViewCellLayout.centerVertically(rLabel, newBounds)

		//  Assign the properties
		self.height = cellHeight
		self.faviconRect = rFavicon
		self.unreadCountRect = rUnread
		self.disclosureButtonRect = rDisclosure
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
