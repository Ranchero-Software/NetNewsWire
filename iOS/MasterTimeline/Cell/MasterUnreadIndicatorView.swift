//
//  MasterUnreadIndicatorView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/16/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit

class MasterUnreadIndicatorView: UIView {

	var isSelected = false {
		didSet {
			setNeedsDisplay()
		}
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		self.isOpaque = false
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.isOpaque = false
	}
	
	static let bezierPath: UIBezierPath = {
		let r = CGRect(x: 0.0, y: 0.0, width: MasterTimelineDefaultCellLayout.unreadCircleDimension, height: MasterTimelineDefaultCellLayout.unreadCircleDimension)
		return UIBezierPath(ovalIn: r)
	}()
	
    override func draw(_ dirtyRect: CGRect) {
		if isSelected {
			AppAssets.selectedTextColor.setFill()
		} else {
			AppAssets.timelineUnreadCircleColor.setFill()
		}
		MasterUnreadIndicatorView.bezierPath.fill()
    }
    
}
