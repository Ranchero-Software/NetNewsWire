//
//  MultilineTextFieldSizerTests.swift
//  RSCore
//
//  Created by Brent Simmons on 6/21/26.
//

#if os(macOS)

import XCTest
import AppKit
@testable import RSCore

// MultilineTextFieldSizer measures text height with NSTextFieldCell.cellSize(forBounds:),
// which skips the Auto Layout engine that NSTextField.fittingSize runs. cellSize lays text
// out inside the cell's content inset, so it wraps a few points narrower than fittingSize at
// a given width — corrected by widening the bounds by cellWidthInsetCompensation points.
//
// This test guards that compensation: it confirms the cellSize path produces the same heights
// as the old fittingSize path across a wide matrix of strings, widths, fonts, and line limits.
// A wrong compensation shows up as a one-line wrap flip (a ~17px jump), which the tolerance
// below catches.

@MainActor final class MultilineTextFieldSizerTests: XCTestCase {

	private let widths = Array(stride(from: 101, through: 699, by: 5))
	private let numberOfLinesCases = [2, 4, 6]

	private lazy var fonts: [NSFont] = {
		[NSFont.systemFont(ofSize: 11), NSFont.systemFont(ofSize: 13), NSFont.boldSystemFont(ofSize: 14)]
	}()

	func testCellSizeMatchesFittingSize() {
		var maxDelta = 0
		var worst = ""
		for string in corpus {
			for font in fonts {
				for numberOfLines in numberOfLinesCases {
					let textField = makeTextField(font, numberOfLines)
					for width in widths {
						let baseline = fittingSizeHeight(textField, string, width)
						let candidate = cellSizeHeight(textField, string, width)
						let delta = abs(baseline - candidate)
						if delta > maxDelta {
							maxDelta = delta
							worst = "width=\(width) lines=\(numberOfLines) font=\(font.pointSize) fittingSize=\(baseline) cellSize=\(candidate) string=\(string.prefix(40).debugDescription)"
						}
					}
				}
			}
		}
		XCTAssertLessThanOrEqual(maxDelta, 1, "cellSize height drifted from fittingSize by \(maxDelta)px — \(worst)")
	}
}

// MARK: - Helpers

private extension MultilineTextFieldSizerTests {

	// The old production measurement, kept here as the reference to match.
	func fittingSizeHeight(_ textField: NSTextField, _ string: String, _ width: Int) -> Int {
		textField.stringValue = string
		textField.preferredMaxLayoutWidth = CGFloat(width)
		return Int(ceil(textField.fittingSize.height))
	}

	// Mirrors the new production measurement.
	func cellSizeHeight(_ textField: NSTextField, _ string: String, _ width: Int) -> Int {
		textField.stringValue = string
		let boundsWidth = CGFloat(width) + cellWidthInsetCompensation
		let bounds = NSRect(x: 0, y: 0, width: boundsWidth, height: CGFloat.greatestFiniteMagnitude)
		guard let cell = textField.cell else {
			return 0
		}
		return Int(ceil(cell.cellSize(forBounds: bounds).height))
	}

	// Must match MultilineTextFieldSizer.cellWidthInsetCompensation.
	var cellWidthInsetCompensation: CGFloat { 4 }

	func makeTextField(_ font: NSFont, _ numberOfLines: Int) -> NSTextField {
		let textField = NSTextField(wrappingLabelWithString: "")
		textField.usesSingleLineMode = false
		textField.maximumNumberOfLines = numberOfLines
		textField.isEditable = false
		textField.font = font
		textField.allowsDefaultTighteningForTruncation = false
		return textField
	}

	var corpus: [String] {
		[
			"Short",
			"A medium length headline that probably wraps once at narrow widths",
			"This is a considerably longer summary of the kind that appears in the timeline when an article has a lot of text and needs several lines to lay out so that wrapping behavior really matters for the height calculation",
			"Title with an explicit\nnewline in the middle",
			"Supercalifragilisticexpialidocious antidisestablishmentarianism pneumonoultramicroscopicsilicovolcanoconiosis",
			"Café résumé naïve — Москва 東京 — emoji 🎉 mixed unicode content that wraps",
			"One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty",
			"",
			"x",
			"Line one\nLine two\nLine three\nLine four\nLine five",
			"Apple announces the next generation of its flagship product line at a special event this fall",
			"Breaking: a remarkably long single sentence with no punctuation that just keeps going on and on so that it has to wrap several times across even a wide timeline column without any natural break points to help it",
			"Trailing whitespace and tabs\t\tand more   ",
			"iOS 26, macOS 26, and the new unified design language across every Apple platform",
			"Q&A: how the team rebuilt the rendering pipeline from scratch — part one of three",
			"A title. Another sentence. And a third one that pushes it onto a second line at most widths."
		]
	}
}

#endif
