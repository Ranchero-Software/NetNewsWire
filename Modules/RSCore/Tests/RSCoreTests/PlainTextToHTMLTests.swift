//
//  PlainTextToHTMLTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import Testing
import RSCore

@Suite struct PlainTextToHTMLTests {

	@Test func youTubeDescription() {
		let text = """
		HomeView recognizes up to six people & keeps <everyone> in the loop.

		Learn more and shop Apple HomeView: https://apple.co/4s4jhly
		Collect 200 by Collect 200: https://music.apple/collect-200


		Siri AI is available in beta.
		"""
		let expected = """
		<p>HomeView recognizes up to six people &amp; keeps &lt;everyone&gt; in the loop.</p>
		<p>Learn more and shop Apple HomeView: <a href="https://apple.co/4s4jhly">https://apple.co/4s4jhly</a><br>
		Collect 200 by Collect 200: <a href="https://music.apple/collect-200">https://music.apple/collect-200</a></p>
		<p>Siri AI is available in beta.</p>
		"""
		#expect(text.convertingPlainTextToHTML == expected)
	}
}
