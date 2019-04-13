//
//  SingleLineTextFieldSizer.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

// Get the size of an NSTextField configured with a specific font with a specific size.
// Uses a cache.
// Main thready only.

final class SingleLineTextFieldSizer {

	let font: NSFont
	private let textField: NSTextField
	private var cache = [String: NSSize]()

	init(font: NSFont) {

		self.textField = NSTextField(labelWithString: "")
		self.textField.font = font
		self.font = font
	}

	func size(for text: String) -> NSSize {

		if let cachedSize = cache[text] {
			return cachedSize
		}

		textField.stringValue = text
		var calculatedSize = textField.fittingSize
		calculatedSize.height = ceil(calculatedSize.height)
		calculatedSize.width = ceil(calculatedSize.width)
		
		cache[text] = calculatedSize
		return calculatedSize
	}

	static private var sizers = [NSFont: SingleLineTextFieldSizer]()

	static func sizer(for font: NSFont) -> SingleLineTextFieldSizer {

		if let cachedSizer = sizers[font] {
			return cachedSizer
		}

		let newSizer = SingleLineTextFieldSizer(font: font)
		sizers[font] = newSizer

		return newSizer
	}

	// Use this call. It’s easiest.

	static func size(for text: String, font: NSFont) -> NSSize {

		return sizer(for: font).size(for: text)
	}

	static func emptyCache() {

		sizers = [NSFont: SingleLineTextFieldSizer]()
	}
}
