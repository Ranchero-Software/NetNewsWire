//
//  MultilineTextFieldSizer.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

// Get the height of an NSTextField given a string, font, and width.
// Uses a cache. Avoids actually measuring text as much as possible.
// Main thread only.

typealias WidthHeightCache = [Int: Int] // width: height

private struct TextFieldSizerSpecifier: Equatable, Hashable {

	let numberOfLines: Int
	let font: NSFont
	let hashValue: Int

	init(numberOfLines: Int, font: NSFont) {
		self.numberOfLines = numberOfLines
		self.font = font
		self.hashValue = font.hashValue ^ numberOfLines
	}

	static func ==(lhs : TextFieldSizerSpecifier, rhs: TextFieldSizerSpecifier) -> Bool {

		return lhs.numberOfLines == rhs.numberOfLines && lhs.font == rhs.font
	}
}

struct TextFieldSizeInfo {

	let size: NSSize // Integral size (ceiled)
	let numberOfLinesUsed: Int // A two-line text field may only use one line, for instance. This would equal 1, then.

	init(size: NSSize, numberOfLinesUsed: Int) {
		self.size = size
		self.numberOfLinesUsed = numberOfLinesUsed
	}
}

final class MultilineTextFieldSizer {

	private let numberOfLines: Int
	private let font: NSFont
	private let textField:NSTextField
	private let singleLineHeightEstimate: Int
	private let doubleLineHeightEstimate: Int
	private var cache = [String: WidthHeightCache]() // Each string has a cache.
	private static var sizers = [TextFieldSizerSpecifier: MultilineTextFieldSizer]()

	private init(numberOfLines: Int, font: NSFont) {

		self.numberOfLines = numberOfLines
		self.font = font
		self.textField = MultilineTextFieldSizer.createTextField(numberOfLines, font)

		self.singleLineHeightEstimate = MultilineTextFieldSizer.calculateHeight("AqLjJ0/y", 200, self.textField)
		self.doubleLineHeightEstimate = MultilineTextFieldSizer.calculateHeight("AqLjJ0/y\nAqLjJ0/y", 200, self.textField)
	}

	static func size(for string: String, font: NSFont, numberOfLines: Int, width: Int) -> TextFieldSizeInfo {

		return sizer(numberOfLines: numberOfLines, font: font).sizeInfo(for: string, width: width)
	}

	static func emptyCache() {

		sizers = [TextFieldSizerSpecifier: MultilineTextFieldSizer]()
	}
}

// MARK: - Private

private extension MultilineTextFieldSizer {

	static func sizer(numberOfLines: Int, font: NSFont) -> MultilineTextFieldSizer {

		let specifier = TextFieldSizerSpecifier(numberOfLines: numberOfLines, font: font)
		if let cachedSizer = sizers[specifier] {
			return cachedSizer
		}

		let newSizer = MultilineTextFieldSizer(numberOfLines: numberOfLines, font: font)
		sizers[specifier] = newSizer
		return newSizer
	}

	func sizeInfo(for string: String, width: Int) -> TextFieldSizeInfo {

		let textFieldHeight = height(for: string, width: width)
		let numberOfLinesUsed = numberOfLines(for: textFieldHeight)

		let size = NSSize(width: width, height: textFieldHeight)
		let sizeInfo = TextFieldSizeInfo(size: size, numberOfLinesUsed: numberOfLinesUsed)
		return sizeInfo
	}

	func height(for string: String, width: Int) -> Int {

		if cache[string] == nil {
			cache[string] = WidthHeightCache()
		}

		if let height = cache[string]![width] {
			return height
		}

		if let height = heightConsideringNeighbors(cache[string]!, width) {
			return height
		}

		let height = calculateHeight(string, width)
		cache[string]![width] = height

		return height
	}

	static func createTextField(_ numberOfLines: Int, _ font: NSFont) -> NSTextField {

		let textField = NSTextField(wrappingLabelWithString: "")
		textField.usesSingleLineMode = false
		textField.maximumNumberOfLines = numberOfLines
		textField.isEditable = false
		textField.font = font
		textField.allowsDefaultTighteningForTruncation = false

		return textField
	}

	func calculateHeight(_ string: String, _ width: Int) -> Int {

		return MultilineTextFieldSizer.calculateHeight(string, width, textField)
	}

	static func calculateHeight(_ string: String, _ width: Int, _ textField: NSTextField) -> Int {

		textField.stringValue = string
		textField.preferredMaxLayoutWidth = CGFloat(width)
		let size = textField.fittingSize
		return Int(ceil(size.height))
	}

	func numberOfLines(for height: Int) -> Int {

		// We’ll have to see if this really works reliably.

		let averageHeight = CGFloat(doubleLineHeightEstimate) / 2.0
		let lines = Int(round(CGFloat(height) / averageHeight))
		return lines
	}

	func heightIsProbablySingleLineHeight(_ height: Int) -> Bool {

		return heightIsProbablyEqualToEstimate(height, singleLineHeightEstimate)
	}

	func heightIsProbablyDoubleLineHeight(_ height: Int) -> Bool {

		return heightIsProbablyEqualToEstimate(height, doubleLineHeightEstimate)
	}

	func heightIsProbablyEqualToEstimate(_ height: Int, _ estimate: Int) -> Bool {

		let slop = 4
		let minimum = estimate - slop
		let maximum = estimate + slop
		return height >= minimum && height <= maximum
	}

	func heightConsideringNeighbors(_ heightCache: WidthHeightCache, _ width: Int) -> Int? {

		// Given width, if the height at width - something and width + something is equal,
		// then that height must be correct for the given width.
		// Also:
		// If a narrower neighbor’s height is single line height, then this wider width must also be single-line height.
		// If a wider neighbor’s height is double line height, and numberOfLines == 2, then this narrower width must able be double-line height.

		var smallNeighbor = (width: 0, height: 0)
		var largeNeighbor = (width: 0, height: 0)

		for (oneWidth, oneHeight) in heightCache {

			if oneWidth < width && heightIsProbablySingleLineHeight(oneHeight) {
				return oneHeight
			}
			if numberOfLines == 2 && oneWidth > width && heightIsProbablyDoubleLineHeight(oneHeight) {
				return oneHeight
			}

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
