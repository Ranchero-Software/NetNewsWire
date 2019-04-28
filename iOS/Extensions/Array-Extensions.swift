//
//  Array-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension Array where Element == CGRect {
	
	func maxY() -> CGFloat {
		
		var y: CGFloat = 0.0
		self.forEach { y = Swift.max(y, $0.maxY) }
		return y
	}
	
}
