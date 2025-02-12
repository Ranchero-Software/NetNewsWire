//
//  UIColor+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 2/12/25.
//

#if os(iOS)

import Foundation
import UIKit

extension UIColor {
	
	public convenience init(hex: String) {
		
		var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
		
		if (s.hasPrefix("#")) {
			s.removeFirst()
		}
		
		var rgb: UInt64 = 0
		Scanner(string: s).scanHexInt64(&rgb)
		
		let red = CGFloat((rgb >> 16) & 0xFF) / 255.0
		let green = CGFloat((rgb >> 8) & 0xFF) / 255.0
		let blue = CGFloat(rgb & 0xFF) / 255.0
		
		self.init(red: red, green: green, blue: blue, alpha: 1.0)
	}
}

#endif
