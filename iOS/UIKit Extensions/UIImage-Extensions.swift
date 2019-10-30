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
		var pixelCount = 0
		var totalLuminance = 0.0
		
		for i in stride(from: 0, to: length, by: 4) {
			
			let r = ptr[i]
			let g = ptr[i + 1]
			let b = ptr[i + 2]
			let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
			
			totalLuminance += luminance
			pixelCount += 1
			
		}
		
		let avgLuminance = totalLuminance / Double(pixelCount)
		return avgLuminance < 37.5
	}
	
}

extension UIImage {
	func isDark() -> Bool {
		return self.cgImage?.isDark() ?? false
	}
}
