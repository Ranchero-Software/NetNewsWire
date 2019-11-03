//
//  MasterUnreadIndicatorView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/16/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import UIKit

class MasterUnreadIndicatorView: UIView {

	override func layoutSubviews() {
		super.layoutSubviews()
		layer.cornerRadius = frame.size.width / 2.0
		clipsToBounds = true
	}
    
}
