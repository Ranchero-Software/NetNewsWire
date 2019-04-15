//
//  UILabelSizerSpecifier.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/19/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import UIKit

// Get the height of an NSTextField given a string, font, and width.
// Uses a cache. Avoids actually measuring text as much as possible.
// Main thread only.

typealias WidthHeightCache = [Int: Int] // width: height

private struct UILabelSizerSpecifier: Hashable {

	let numberOfLines: Int
	let font: UIFont
}

struct TextFieldSizeInfo {

	let size: CGSize // Integral size (ceiled)
	let numberOfLinesUsed: Int // A two-line text field may only use one line, for instance. This would equal 1, then.
}

final class MultilineUILabelSizer {

	private let numberOfLines: Int
	private let font: UIFont
	private let singleLineHeightEstimate: Int
	private let doubleLineHeightEstimate: Int
	private var cache = [String: WidthHeightCache]() // Each string has a cache.
	private static var sizers = [UILabelSizerSpecifier: MultilineUILabelSizer]()

	private init(numberOfLines: Int, font: UIFont) {

		self.numberOfLines = numberOfLines
		self.font = font

		self.singleLineHeightEstimate = MultilineUILabelSizer.calculateHeight("AqLjJ0/y", 200, font)
		self.doubleLineHeightEstimate = MultilineUILabelSizer.calculateHeight("AqLjJ0/y\nAqLjJ0/y", 200, font)
		
	}

	static func size(for string: String, font: UIFont, numberOfLines: Int, width: Int) -> TextFieldSizeInfo {
		return sizer(numberOfLines: numberOfLines, font: font).sizeInfo(for: string, width: width)
	}

	static func emptyCache() {
		sizers = [UILabelSizerSpecifier: MultilineUILabelSizer]()
	}
	
}

// MARK: - Private

private extension MultilineUILabelSizer {

	static func sizer(numberOfLines: Int, font: UIFont) -> MultilineUILabelSizer {

		let specifier = UILabelSizerSpecifier(numberOfLines: numberOfLines, font: font)
		if let cachedSizer = sizers[specifier] {
			return cachedSizer
		}

		let newSizer = MultilineUILabelSizer(numberOfLines: numberOfLines, font: font)
		sizers[specifier] = newSizer
		return newSizer
		
	}

	func sizeInfo(for string: String, width: Int) -> TextFieldSizeInfo {

		let textFieldHeight = height(for: string, width: width)
		let numberOfLinesUsed = numberOfLines(for: textFieldHeight)

		let size = CGSize(width: width, height: textFieldHeight)
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

		var height = MultilineUILabelSizer.calculateHeight(string, width, font)
		let maxHeight = singleLineHeightEstimate * numberOfLines
		if height > maxHeight {
			height = maxHeight
		}
		
		cache[string]![width] = height

		return height
	}

	static func calculateHeight(_ string: String, _ width: Int, _ font: UIFont) -> Int {
		let height = string.height(withConstrainedWidth: CGFloat(width), font: font)
		return Int(ceil(height))
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
