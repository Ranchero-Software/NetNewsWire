//
//  MasterTimelineUnreadCountView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/30/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class MasterTimelineUnreadCountView: MasterFeedUnreadCountView {

	override var textColor: UIColor {
		return UIColor.systemBackground
	}
	
	override var intrinsicContentSize: CGSize {
		return contentSize
	}
	
	override func draw(_ dirtyRect: CGRect) {

		let cornerRadii = CGSize(width: cornerRadius, height: cornerRadius)
		let rect = CGRect(x: 1, y: 1, width: bounds.width - 2, height: bounds.height - 2)
		let path = UIBezierPath(roundedRect: rect, byRoundingCorners: .allCorners, cornerRadii: cornerRadii)
		AppAssets.primaryAccentColor.setFill()
		path.fill()

		if unreadCount > 0 {
			unreadCountString.draw(at: textRect().origin, withAttributes: textAttributes)
		}
		
	}
	
}
