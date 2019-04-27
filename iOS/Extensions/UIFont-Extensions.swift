//
//  UIFont-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/27/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension UIFont {
	
	func withTraits(traits:UIFontDescriptor.SymbolicTraits) -> UIFont {
		let descriptor = fontDescriptor.withSymbolicTraits(traits)
		return UIFont(descriptor: descriptor!, size: 0) //size 0 means keep the size as it is
	}
	
	func bold() -> UIFont {
		return withTraits(traits: .traitBold)
	}
	
	func italic() -> UIFont {
		return withTraits(traits: .traitItalic)
	}
	
}
