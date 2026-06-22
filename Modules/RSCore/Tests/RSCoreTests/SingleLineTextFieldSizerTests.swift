//
//  SingleLineTextFieldSizerTests.swift
//  RSCore
//
//  Created by Brent Simmons on 6/21/26.
//

#if os(macOS)

import XCTest
import AppKit
@testable import RSCore

// SingleLineTextFieldSizer measures with NSTextFieldCell.cellSize, which skips the Auto Layout
// engine that NSTextField.fittingSize runs. For a single-line label the two match exactly on both
// width and height (no inset compensation needed). This test guards that equivalence — both
// dimensions matter, since the timeline uses the measured width to position the date and feed name.

@MainActor final class SingleLineTextFieldSizerTests: XCTestCase {

	private lazy var fonts: [NSFont] = {
		[NSFont.systemFont(ofSize: 11), NSFont.systemFont(ofSize: 12), NSFont.systemFont(ofSize: 13), NSFont.boldSystemFont(ofSize: 14)]
	}()

	func testCellSizeMatchesFittingSize() {
		var maxWidthDelta = 0
		var maxHeightDelta = 0
		var worst = ""

		for font in fonts {
			let textField = NSTextField(labelWithString: "")
			textField.font = font
			guard let cell = textField.cell else {
				continue
			}

			for string in corpus {
				textField.stringValue = string

				let fitting = textField.fittingSize
				let baselineWidth = Int(ceil(fitting.width))
				let baselineHeight = Int(ceil(fitting.height))

				let measured = cell.cellSize
				let candidateWidth = Int(ceil(measured.width))
				let candidateHeight = Int(ceil(measured.height))

				let widthDelta = abs(baselineWidth - candidateWidth)
				let heightDelta = abs(baselineHeight - candidateHeight)
				if widthDelta > maxWidthDelta || heightDelta > maxHeightDelta {
					worst = "font=\(font.pointSize) fittingSize=(\(baselineWidth),\(baselineHeight)) cellSize=(\(candidateWidth),\(candidateHeight)) string=\(string.prefix(30).debugDescription)"
				}
				maxWidthDelta = max(maxWidthDelta, widthDelta)
				maxHeightDelta = max(maxHeightDelta, heightDelta)
			}
		}

		XCTAssertLessThanOrEqual(maxWidthDelta, 1, "cellSize width drifted from fittingSize by \(maxWidthDelta)px — \(worst)")
		XCTAssertLessThanOrEqual(maxHeightDelta, 1, "cellSize height drifted from fittingSize by \(maxHeightDelta)px — \(worst)")
	}

	private var corpus: [String] {
		[
			"", "x", "Today", "Yesterday", "Jan 5", "5:42 PM",
			"December 31, 2026 at 11:59 PM",
			"Daring Fireball", "NetNewsWire Blog", "The Verge — Tech",
			"A fairly long single-line feed name that goes on for a while",
			"Café résumé — Москва 東京 🎉",
			"J. R. R. Tolkien", "12,345 unread"
		]
	}
}

#endif
