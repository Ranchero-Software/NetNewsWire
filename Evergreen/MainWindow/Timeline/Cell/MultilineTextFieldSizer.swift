//
//  MultilineTextFieldSizer.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

// Get the height of an NSTextField given an NSAttributedString and a width.
// Uses a cache. Avoids actually measuring text as much as possible.
// Main thread only.

typealias WidthHeightCache = [Int: Int] // width: height

final class MultilineTextFieldSizer {

	private let numberOfLines: Int
	private let textField:NSTextField
	private var cache = [NSAttributedString: WidthHeightCache]() // Each string has a cache.
	private static var sizers = [Int: MultilineTextFieldSizer]()

	private init(numberOfLines: Int) {

		self.numberOfLines = numberOfLines
		self.textField = MultilineTextFieldSizer.createTextField(numberOfLines)
	}

	static func size(for attributedString: NSAttributedString, numberOfLines: Int, width: Int) -> Int {

		return sizer(numberOfLines: numberOfLines).height(for: attributedString, width: width)
	}

	static func emptyCache() {

		sizers = [Int: MultilineTextFieldSizer]()
	}
}

// MARK: - Private

private extension MultilineTextFieldSizer {

	static func sizer(numberOfLines: Int) -> MultilineTextFieldSizer {

		if let cachedSizer = sizers[numberOfLines] {
			return cachedSizer
		}

		let newSizer = MultilineTextFieldSizer(numberOfLines: numberOfLines)
		sizers[numberOfLines] = newSizer
		return newSizer
	}

	func height(for attributedString: NSAttributedString, width: Int) -> Int {

		if cache[attributedString] == nil {
			cache[attributedString] = WidthHeightCache()
		}

		if let height = cache[attributedString]![width] {
			return height
		}

		if let height = heightConsideringNeighbors(cache[attributedString]!, width) {
			return height
		}

		let height = calculateHeight(attributedString, width)
		cache[attributedString]![width] = height

		return height
	}

	static func createTextField(_ numberOfLines: Int) -> NSTextField {

		let textField = NSTextField(wrappingLabelWithString: "")
		textField.usesSingleLineMode = false
		textField.maximumNumberOfLines = numberOfLines
		textField.isEditable = false

		return textField
	}

	func calculateHeight(_ attributedString: NSAttributedString, _ width: Int) -> Int {

		textField.attributedStringValue = attributedString
		textField.preferredMaxLayoutWidth = CGFloat(width)
		let size = textField.fittingSize
		return Int(ceil(size.height))
	}

//	func widthHeightCache(for attributedString: NSAttributedString) -> WidthHeightCache {
//
//		if let foundCache = cache[attributedString] {
//			return foundCache
//		}
//		let newCache = WidthHeightCache()
//		cache[attributedString] = newCache
//		return newCache
//	}

	func heightConsideringNeighbors(_ heightCache: WidthHeightCache, _ width: Int) -> Int? {

		// Given width, if the height at width - something and width + something is equal,
		// then that height must be correct for the given width.

		var smallNeighbor = (width: 0, height: 0)
		var largeNeighbor = (width: 0, height: 0)

		for (oneWidth, oneHeight) in heightCache {

			if oneWidth < width && (oneWidth > smallNeighbor.width || smallNeighbor.width == 0) {
				smallNeighbor = (oneWidth, oneHeight)
			}
			else if oneWidth > width && (oneWidth < largeNeighbor.width || largeNeighbor.width == 0) {
				largeNeighbor = (oneWidth, oneHeight)
			}

			if smallNeighbor.width != 0 && smallNeighbor.height == largeNeighbor.height {
				return smallNeighbor.height
			}
		}

		return nil
	}
}
