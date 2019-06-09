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

	/// Get the NSTextField size for text, given a font.
	static func size(for text: String, font: NSFont) -> NSSize {
		return sizer(for: font).size(for: text)
	}

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

	static private var sizers = [SingleLineTextFieldSizer]()

	static private func sizer(for font: NSFont) -> SingleLineTextFieldSizer {
		// We used to use an [NSFont: SingleLineTextFieldSizer] dictionary —
		// until, in 10.14.5, we started getting crashes with the message:
		//    Fatal error: Duplicate keys of type 'NSFont' were found in a Dictionary.
		//    This usually means either that the type violates Hashable's requirements, or
		//    that members of such a dictionary were mutated after insertion.
		// We use just an array of sizers now — which is totally fine,
		// because there’s only going to be like three of them.
		if let cachedSizer = sizers.firstElementPassingTest({ $0.font == font }) {
			return cachedSizer
		}

		let newSizer = SingleLineTextFieldSizer(font: font)
		sizers.append(newSizer)

		return newSizer
	}
}
