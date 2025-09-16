//
//  MacroProcessorTests.swift
//  RSCoreTests
//
//  Created by Nate Weaver on 2020-01-01.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSCore

final class MacroProcessorTests: XCTestCase {
	let substitutions = ["one": "1", "two": "2"]

	func testMacroProcessor() {
		var template = "foo [[one]] bar [[two]] baz"
		var expected = "foo 1 bar 2 baz"
		var result = try! MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions)
		XCTAssertEqual(result, expected)

		template = "[[one]] foo [[two]] bar"
		expected = "1 foo 2 bar"
		result = try! MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions)
		XCTAssertEqual(result, expected)

		template = "foo [[one]] bar [[two]]"
		expected = "foo 1 bar 2"
		result = try! MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions)
		XCTAssertEqual(result, expected)

		// Nonexistent key
		template = "foo [[nonexistent]] bar"
		expected = template
		result = try! MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions)
		XCTAssertEqual(result, expected)

		// Equal delimiters
		template = "foo |one| bar |two| baz"
		expected = "foo 1 bar 2 baz"
		result = try! MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions, macroStart: "|", macroEnd: "|")
		XCTAssertEqual(result, expected)
	}

	func testEmptyDelimiters() {
		do {
			let template = "foo bar"
			let _ = try MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions, macroStart: "")
			XCTFail("Error should be thrown")
		} catch {
			// Success
		}

		do {
			let template = "foo bar"
			let _ = try MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions, macroEnd: "")
			XCTFail("Error should be thrown")
		} catch {
			// Success
		}

	}

	// Macro replacement shouldn't be recursive
	func testMacroInSubstitutions() {
		let substitutions = ["one": "[[two]]", "two": "2"]
		let template = "foo [[one]] bar"
		let expected = "foo [[two]] bar"
		let result = try! MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions)
		XCTAssertEqual(result, expected)
	}
}
