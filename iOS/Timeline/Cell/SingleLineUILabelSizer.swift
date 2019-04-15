//
//  SingleLineUILabelSizer.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import UIKit

// Get the size of an UILabel configured with a specific font with a specific size.
// Uses a cache.
// Main thready only.

final class SingleLineUILabelSizer {

	let font: UIFont
	private var cache = [String: CGSize]()

	init(font: UIFont) {
		self.font = font
	}

	func size(for text: String) -> CGSize {

		if let cachedSize = cache[text] {
			return cachedSize
		}

		let height = text.height(withConstrainedWidth: .greatestFiniteMagnitude, font: font)
		let width = text.width(withConstrainedHeight: .greatestFiniteMagnitude, font: font)
		let calculatedSize = CGSize(width: ceil(width), height: ceil(height))
		
		cache[text] = calculatedSize
		return calculatedSize
		
	}

	static private var sizers = [UIFont: SingleLineUILabelSizer]()

	static func sizer(for font: UIFont) -> SingleLineUILabelSizer {

		if let cachedSizer = sizers[font] {
			return cachedSizer
		}

		let newSizer = SingleLineUILabelSizer(font: font)
		sizers[font] = newSizer

		return newSizer
		
	}

	// Use this call. It’s easiest.

	static func size(for text: String, font: UIFont) -> CGSize {
		return sizer(for: font).size(for: text)
	}

	static func emptyCache() {
		sizers = [UIFont: SingleLineUILabelSizer]()
	}
	
}
