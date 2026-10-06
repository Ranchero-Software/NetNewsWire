//
//  SingleLineUILabelSizer.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import UIKit

// Get the size of a UILabel configured with a specific font. Uses a cache. Main thread only.

@MainActor final class SingleLineUILabelSizer {

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

	private static var sizers = [UIFont: SingleLineUILabelSizer]()

	static func sizer(for font: UIFont) -> SingleLineUILabelSizer {
		if let cachedSizer = sizers[font] {
			return cachedSizer
		}
		let newSizer = SingleLineUILabelSizer(font: font)
		sizers[font] = newSizer
		return newSizer
	}

	static func size(for text: String, font: UIFont) -> CGSize {
		sizer(for: font).size(for: text)
	}

	static func emptyCache() {
		sizers = [UIFont: SingleLineUILabelSizer]()
	}
}
