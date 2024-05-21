//
//  MacroProcessorTests.swift
//  
//
//  Created by Brent Simmons on 5/20/24.
//

import XCTest
import Core

final class MacroProcessorTests: XCTestCase {

	func testOneMacro() {

		let template = "<html><head><body>{content}</body></head></html>"
		let substitutions = ["content": "This is the content."]

		let renderedText = try! MacroProcessor.renderedText(withTemplate: template, substitutions: substitutions, macroStart: "{", macroEnd: "}")
		let expectedText = "<html><head><body>This is the content.</body></head></html>"
		XCTAssertEqual(renderedText, expectedText)
	}
}
