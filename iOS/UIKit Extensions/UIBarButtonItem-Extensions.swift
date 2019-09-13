//
//  UIBarButtonItem-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/27/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

public extension UIBarButtonItem {
	
	@IBInspectable var accEnabled: Bool {
		get {
			return isAccessibilityElement
		}
		set {
			isAccessibilityElement = newValue
		}
	}
	
	@IBInspectable var accLabelText: String? {
		get {
			return accessibilityLabel
		}
		set {
			accessibilityLabel = newValue
		}
	}
	
	var isHidden: Bool {
		get {
			return tintColor == UIColor.clear
		}
		set(hide) {
			if hide {
				isEnabled = false
				tintColor = UIColor.clear
			} else {
				isEnabled = true
				tintColor = nil 
			}
		}
	}
	
}
