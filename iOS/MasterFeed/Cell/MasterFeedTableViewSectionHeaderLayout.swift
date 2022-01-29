//
//  MasterFeedTableViewSectionHeaderLayout.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

struct MasterFeedTableViewSectionHeaderLayout {

	private static let labelMarginRight = CGFloat(integerLiteral: 8)
	private static let disclosureButtonSize = CGSize(width: 44, height: 44)
	private static let verticalPadding = CGFloat(integerLiteral: 11)

	private static let minRowHeight = CGFloat(integerLiteral: 44)
	
	let titleRect: CGRect
	let disclosureButtonRect: CGRect
	
	let height: CGFloat
	
	init(cellWidth: CGFloat, insets: UIEdgeInsets, label: UILabel) {

		let bounds = CGRect(x: insets.left, y: 0.0, width: floor(cellWidth - insets.right), height: 0.0)
		
		// Disclosure Button
		var rDisclosure = CGRect.zero
		rDisclosure.size = MasterFeedTableViewSectionHeaderLayout.disclosureButtonSize
		rDisclosure.origin.x = bounds.maxX - rDisclosure.size.width


		// Title
		let rLabelx = 15.0
		let rLabely = UIFontMetrics.default.scaledValue(for: MasterFeedTableViewSectionHeaderLayout.verticalPadding)
		
		var labelWidth = CGFloat.zero
		labelWidth = cellWidth - (rLabelx + MasterFeedTableViewSectionHeaderLayout.labelMarginRight)
		
		let labelSizeInfo = MultilineUILabelSizer.size(for: label.text ?? "", font: label.font, numberOfLines: 0, width: Int(floor(labelWidth)))
		var rLabel = CGRect(x: rLabelx, y: rLabely, width: labelWidth, height: labelSizeInfo.size.height)
		
		// Determine cell height
		let paddedLabelHeight = rLabel.maxY + UIFontMetrics.default.scaledValue(for: MasterFeedTableViewSectionHeaderLayout.verticalPadding)
		let maxGraphicsHeight = [rDisclosure].maxY()
		var cellHeight = max(paddedLabelHeight, maxGraphicsHeight)
		if cellHeight < MasterFeedTableViewSectionHeaderLayout.minRowHeight {
			cellHeight = MasterFeedTableViewSectionHeaderLayout.minRowHeight
		}
		
		// Center in Cell
		let newBounds = CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: cellHeight)
		rDisclosure = MasterFeedTableViewCellLayout.centerVertically(rDisclosure, newBounds)

		// Small fonts need centered if we hit the minimum row height
		if cellHeight == MasterFeedTableViewSectionHeaderLayout.minRowHeight {
			rLabel = MasterFeedTableViewCellLayout.centerVertically(rLabel, newBounds)
		}
		
		//  Assign the properties
		self.height = cellHeight
		self.disclosureButtonRect = rDisclosure
		self.titleRect = rLabel
		
	}
	
}
