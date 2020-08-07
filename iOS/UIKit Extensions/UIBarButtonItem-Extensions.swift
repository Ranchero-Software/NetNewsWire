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
	
}
