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

	private static let indent = CGFloat(integerLiteral: 14)
	private static let editingControlIndent = CGFloat(integerLiteral: 40)
	private static let imageSize = CGSize(width: 16, height: 16)
	private static let marginLeft = CGFloat(integerLiteral: 8)
	private static let imageMarginRight = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginLeft = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginRight = CGFloat(integerLiteral: 0)
	private static let disclosureButtonSize = CGSize(width: 44, height: 44)
	
	let faviconRect: CGRect
	let titleRect: CGRect
	let unreadCountRect: CGRect
	let disclosureButtonRect: CGRect
	
	init(cellSize: CGSize, insets: UIEdgeInsets, shouldShowImage: Bool, label: UILabel, unreadCountView: MasterFeedUnreadCountView, showingEditingControl: Bool, indent: Bool, shouldShowDisclosure: Bool) {

		var initialIndent = MasterFeedTableViewCellLayout.marginLeft + insets.left
		if indent {
			initialIndent += MasterFeedTableViewCellLayout.indent
		}
		if showingEditingControl {
			initialIndent += MasterFeedTableViewCellLayout.editingControlIndent
		}
		
		let bounds = CGRect(x: initialIndent, y: 0.0, width: floor(cellSize.width - initialIndent - insets.right), height: floor(cellSize.height))
		
		// Favicon
		var rFavicon = CGRect.zero
		if shouldShowImage {
			rFavicon = CGRect(x: bounds.origin.x, y: 0.0, width: MasterFeedTableViewCellLayout.imageSize.width, height: MasterFeedTableViewCellLayout.imageSize.height)
			rFavicon = MasterFeedTableViewCellLayout.centerVertically(rFavicon, bounds)
		}
		self.faviconRect = rFavicon

		// Title
		let labelSize = SingleLineUILabelSizer.size(for: label.text ?? "", font: label.font!)

		var rLabel = CGRect(x: 0.0, y: 0.0, width: labelSize.width, height: labelSize.height)
		if shouldShowImage {
			rLabel.origin.x = rFavicon.maxX + MasterFeedTableViewCellLayout.imageMarginRight
		} else {
			rLabel.origin.x = bounds.minX
		}
		
		rLabel = MasterFeedTableViewCellLayout.centerVertically(rLabel, bounds)

		// Unread Count
		let unreadCountSize = unreadCountView.intrinsicContentSize
		let unreadCountIsHidden = unreadCountView.unreadCount < 1

		var rUnread = CGRect.zero
		if !unreadCountIsHidden {
			
			rUnread.size = unreadCountSize
			rUnread.origin.x = bounds.maxX -
				(unreadCountSize.width + MasterFeedTableViewCellLayout.unreadCountMarginRight + MasterFeedTableViewCellLayout.disclosureButtonSize.width)
			rUnread = MasterFeedTableViewCellLayout.centerVertically(rUnread, bounds)
			
			// Cap the Title width based on the unread indicator button
			let labelMaxX = rUnread.minX - MasterFeedTableViewCellLayout.unreadCountMarginLeft
			if rLabel.maxX > labelMaxX {
				rLabel.size.width = labelMaxX - rLabel.minX
			}
			
		}
		self.unreadCountRect = rUnread
		
		// Disclosure Button
		var rDisclosure = CGRect.zero
		if shouldShowDisclosure {
			
			rDisclosure.size = MasterFeedTableViewCellLayout.disclosureButtonSize
			rDisclosure.origin.x = bounds.maxX - MasterFeedTableViewCellLayout.disclosureButtonSize.width
			rDisclosure = MasterFeedTableViewCellLayout.centerVertically(rDisclosure, bounds)
			
			// Cap the Title width based on the disclosure button
			let labelMaxX = rDisclosure.minX
			if rLabel.maxX > labelMaxX {
				rLabel.size.width = labelMaxX - rLabel.minX
			}
		
		}
		self.disclosureButtonRect = rDisclosure

		
		// Cap the Title width based on total width
		if rLabel.maxX > bounds.maxX {
			rLabel.size.width = bounds.maxX - rLabel.minX
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
