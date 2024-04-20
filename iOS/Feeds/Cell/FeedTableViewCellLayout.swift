//
//  TableViewCellLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit

struct FeedTableViewCellLayout {

	private static let indentWidth = CGFloat(integerLiteral: 42)
	private static let editingControlIndent = CGFloat(integerLiteral: 40)
	private static let imageSize = CGSize(width: 24, height: 24)
	private static let imageMarginRight = CGFloat(integerLiteral: 11)
	private static let labelMarginRight = CGFloat(integerLiteral: 8)
	private static let unreadCountMarginRight = CGFloat(integerLiteral: 16)
	private static let disclosureButtonSize = CGSize(width: 44, height: 44)
	private static let verticalPadding = CGFloat(integerLiteral: 11)

	private static let minRowHeight = CGFloat(integerLiteral: 44)
	
	static let faviconCornerRadius = CGFloat(integerLiteral: 2)

	let faviconRect: CGRect
	let titleRect: CGRect
	let unreadCountRect: CGRect
	let disclosureButtonRect: CGRect
	let separatorRect: CGRect
	
	let height: CGFloat
	
	@MainActor init(cellWidth: CGFloat, insets: UIEdgeInsets, label: UILabel, unreadCountView: FeedUnreadCountView, showingEditingControl: Bool, indent: Bool, shouldShowDisclosure: Bool) {

		var initialIndent = insets.left
		if indent {
			initialIndent += FeedTableViewCellLayout.indentWidth
		}
		let bounds = CGRect(x: initialIndent, y: 0.0, width: floor(cellWidth - initialIndent - insets.right), height: 0.0)
		
		// Disclosure Button
		var rDisclosure = CGRect.zero
		if shouldShowDisclosure {
			rDisclosure.size = FeedTableViewCellLayout.disclosureButtonSize
			rDisclosure.origin.x = bounds.origin.x
		}

		// Favicon
		var rFavicon = CGRect.zero
		if !shouldShowDisclosure {
			let x = bounds.origin.x
			let y = UIFontMetrics.default.scaledValue(for: FeedTableViewCellLayout.verticalPadding) +
				label.font.lineHeight / 2.0 -
				FeedTableViewCellLayout.imageSize.height / 2.0
			rFavicon = CGRect(x: x, y: y, width: FeedTableViewCellLayout.imageSize.width, height: FeedTableViewCellLayout.imageSize.height)
		}

		// Unread Count
		let unreadCountSize = unreadCountView.contentSize
		let unreadCountIsHidden = unreadCountView.unreadCount < 1

		var rUnread = CGRect.zero
		if !unreadCountIsHidden {
			rUnread.size = unreadCountSize
			rUnread.origin.x = bounds.maxX - (FeedTableViewCellLayout.unreadCountMarginRight + unreadCountSize.width)
		}
		
		// Title
		var rLabelx = insets.left + FeedTableViewCellLayout.disclosureButtonSize.width
		if !shouldShowDisclosure {
			rLabelx = rLabelx + FeedTableViewCellLayout.imageSize.width + FeedTableViewCellLayout.imageMarginRight
		}
		let rLabely = UIFontMetrics.default.scaledValue(for: FeedTableViewCellLayout.verticalPadding)
		
		var labelWidth = CGFloat.zero
		if !unreadCountIsHidden {
			labelWidth = cellWidth - (rLabelx + FeedTableViewCellLayout.labelMarginRight + (cellWidth - rUnread.minX))
		} else {
			labelWidth = cellWidth - (rLabelx + FeedTableViewCellLayout.labelMarginRight)
		}
		
		let labelSizeInfo = MultilineUILabelSizer.size(for: label.text ?? "", font: label.font, numberOfLines: 0, width: Int(floor(labelWidth)))

		// Now that we've got everything (especially the label) computed without the editing controls, update for them.
		// We do this because we don't want the row height to change when the editing controls are brought out.  We will
		// handle the missing space, but removing it from the label and truncating.
		if showingEditingControl {
			rDisclosure.origin.x += FeedTableViewCellLayout.editingControlIndent
			rFavicon.origin.x += FeedTableViewCellLayout.editingControlIndent
			rLabelx += FeedTableViewCellLayout.editingControlIndent
			if !unreadCountIsHidden {
				rUnread.origin.x -= FeedTableViewCellLayout.editingControlIndent
				labelWidth = cellWidth - (rLabelx + FeedTableViewCellLayout.labelMarginRight + (cellWidth - rUnread.minX))
			} else {
				labelWidth = cellWidth - (rLabelx + FeedTableViewCellLayout.labelMarginRight + FeedTableViewCellLayout.editingControlIndent)
			}
		}

		var rLabel = CGRect(x: rLabelx, y: rLabely, width: labelWidth, height: labelSizeInfo.size.height)
		
		// Determine cell height
		let paddedLabelHeight = rLabel.maxY + UIFontMetrics.default.scaledValue(for: FeedTableViewCellLayout.verticalPadding)
		let maxGraphicsHeight = [rFavicon, rUnread, rDisclosure].maxY()
		var cellHeight = max(paddedLabelHeight, maxGraphicsHeight)
		if cellHeight < FeedTableViewCellLayout.minRowHeight {
			cellHeight = FeedTableViewCellLayout.minRowHeight
		}
		
		// Center in Cell
		let newBounds = CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: cellHeight)
		if !unreadCountIsHidden {
			rUnread = FeedTableViewCellLayout.centerVertically(rUnread, newBounds)
		}
		if shouldShowDisclosure {
			rDisclosure = FeedTableViewCellLayout.centerVertically(rDisclosure, newBounds)
		}

		// Small fonts and the Favicon need centered if we hit the minimum row height
		if cellHeight == FeedTableViewCellLayout.minRowHeight {
			rLabel = FeedTableViewCellLayout.centerVertically(rLabel, newBounds)
			rFavicon = FeedTableViewCellLayout.centerVertically(rFavicon, newBounds)
		}

		//  Separator Insets
		let separatorInset = FeedTableViewCellLayout.disclosureButtonSize.width
		separatorRect = CGRect(x: separatorInset, y: cellHeight - 0.5, width: cellWidth - separatorInset, height: 0.5)
		
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
