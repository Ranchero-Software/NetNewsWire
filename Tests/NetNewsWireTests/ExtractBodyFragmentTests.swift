//
//  ExtractBodyFragmentTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 7/30/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing

@testable import NetNewsWire

/// Tests for `ArticleRenderingSpecialCases.extractBodyFragmentIfNeeded(_:)`.
/// <https://github.com/Ranchero-Software/NetNewsWire/issues/3008>
@Suite struct ExtractBodyFragmentTests {

	private func extracted(_ html: String) -> String {
		ArticleRenderingSpecialCases.extractBodyFragmentIfNeeded(html)
	}

	@Test func fullDocumentYieldsBodyFragmentOnly() {
		let html = """
		<!doctype html>
		<html xmlns="http://www.w3.org/1999/xhtml">
		<head><style>body { background: #FAFAFA; }</style></head>
		<body style="background-color: #FAFAFA;margin: 0;"><p>Newsletter content</p></body>
		</html>
		"""
		#expect(extracted(html) == "<p>Newsletter content</p>")
	}

	@Test func uppercaseBodyTag() {
		let html = "<HTML><BODY BGCOLOR=\"white\"><p>x</p></BODY></HTML>"
		#expect(extracted(html) == "<p>x</p>")
	}

	@Test func unclosedBodyRunsToEnd() {
		let html = "<html><body class=\"c\"><p>one</p><p>two</p>"
		#expect(extracted(html) == "<p>one</p><p>two</p>")
	}

	@Test func documentWithoutBodyTagLosesWrapper() {
		let html = "<!DOCTYPE html><html lang=\"en\"><head><title>t</title></head><p>content</p></html>"
		#expect(extracted(html) == "<p>content</p>")
	}

	@Test func doctypeOnlyPrefixIsRemoved() {
		let html = "<!doctype html><p>content</p>"
		#expect(extracted(html) == "<p>content</p>")
	}

	@Test func plainFragmentIsUnchanged() {
		let html = "<p>Just a normal article <b>fragment</b>.</p>"
		#expect(extracted(html) == html)
	}

	@Test func bodyPrefixedTagIsNotMistakenForBodyTag() {
		// <bodyguard> isn't a body tag — and with no real document markers
		// beyond it, nothing should change.
		let html = "<p>The <bodyguard>stood</bodyguard> watch.</p>"
		#expect(extracted(html) == html)
	}

	@Test func headerElementSurvivesDocumentUnwrapping() {
		// <header>/<head> confusion: the header element must not be
		// treated as the head block.
		let html = "<html><header><h1>Title</h1></header><p>content</p></html>"
		#expect(extracted(html) == "<header><h1>Title</h1></header><p>content</p>")
	}
}
