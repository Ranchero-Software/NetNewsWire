//
//  UIImage-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension CGImage {

	func isDark() -> Bool {
		guard let imageData = self.dataProvider?.data else { return false }
		guard let ptr = CFDataGetBytePtr(imageData) else { return false }
		
		let length = CFDataGetLength(imageData)
		var visiblePixels = 0
		var darkPixels = 0
		
		for i in stride(from: 0, to: length, by: 4) {
			
			let r = ptr[i]
			let g = ptr[i + 1]
			let b = ptr[i + 2]
			let a = ptr[i + 3]
			let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
			
			if Double(a) > 0.0 {
				visiblePixels += 1
				if luminance < 50 {
					darkPixels += 1
				}
			}
			
		}
		
		return Double(darkPixels) / Double(visiblePixels) > 0.4
	}
	
}

extension UIImage {
	func isDark() -> Bool {
		return self.cgImage?.isDark() ?? false
	}
}
