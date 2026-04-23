//
//  NSAttributedStringHTMLTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import XCTest
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

@testable import NetNewsWire

@MainActor final class NSAttributedStringHTMLTests: XCTestCase {

	// MARK: - Plain text / basic tags

	func testPlainText() {
		let s = NSAttributedString(simpleHTML: "Hello World")
		XCTAssertEqual(s.string, "Hello World")
	}

	func testBoldTag() {
		let s = NSAttributedString(simpleHTML: "Use <b>bold</b> here")
		XCTAssertEqual(s.string, "Use bold here")
	}

	func testItalicTag() {
		let s = NSAttributedString(simpleHTML: "Use <i>italic</i> here")
		XCTAssertEqual(s.string, "Use italic here")
	}

	func testMultipleTags() {
		let s = NSAttributedString(simpleHTML: "<b>Bold</b> and <i>italic</i> together")
		XCTAssertEqual(s.string, "Bold and italic together")
	}

	// MARK: - Entities

	func testAmpersandEntity() {
		let s = NSAttributedString(simpleHTML: "Tom &amp; Jerry")
		XCTAssertEqual(s.string, "Tom & Jerry")
	}

	func testMixedEntitiesAndTags() {
		let s = NSAttributedString(simpleHTML: "<b>Tom</b> &amp; <i>Jerry</i>")
		XCTAssertEqual(s.string, "Tom & Jerry")
	}

	// MARK: - <q> tags (locale-dependent quotes)

	func testQTagProducesQuotes() {
		// Use en_US locale for deterministic output — else this depends
		// on the test-runner locale.
		let s = NSAttributedString(simpleHTML: "<q>hi</q>", locale: Locale(identifier: "en_US"))
		XCTAssertTrue(s.string.contains("hi"))
		// en_US uses curly quotes — confirm something was added.
		XCTAssertGreaterThan(s.string.count, 2)
	}

	// MARK: - Attribute application

	// Bold text should have a bold-weighted font.
	func testBoldFontIsApplied() {
		let s = NSAttributedString(simpleHTML: "<b>Bold</b>")
		let font = s.attribute(.font, at: 0, effectiveRange: nil) as? RSFont
		XCTAssertNotNil(font)
		let traits = font?.fontDescriptor.symbolicTraits
		XCTAssertNotNil(traits)
		#if canImport(AppKit)
		XCTAssertTrue(traits!.contains(.bold))
		#else
		XCTAssertTrue(traits!.contains(.traitBold))
		#endif
	}

	// Underline should carry the underline attribute.
	func testUnderlineIsApplied() {
		let s = NSAttributedString(simpleHTML: "<u>Underlined</u>")
		let underline = s.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
		XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
	}

	// MARK: - Unicode

	func testUnicodeText() {
		let s = NSAttributedString(simpleHTML: "Café résumé 🎉")
		XCTAssertEqual(s.string, "Café résumé 🎉")
	}

	func testUnicodeInsideTag() {
		let s = NSAttributedString(simpleHTML: "<b>Café résumé</b>")
		XCTAssertEqual(s.string, "Café résumé")
	}

}
