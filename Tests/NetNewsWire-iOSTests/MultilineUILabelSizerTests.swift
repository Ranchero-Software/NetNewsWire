//
//  MultilineUILabelSizerTests.swift
//  NetNewsWire-iOSTests
//
//  Created by Brent Simmons on 8/6/26.
//

import Testing
import UIKit
@testable import NetNewsWire

@MainActor @Suite struct MultilineUILabelSizerTests {

	@Test func negativeWidthMeasurementIsNotCached() {
		MultilineUILabelSizer.emptyCache()

		let string = "A title long enough that it must wrap onto more than one line at two hundred points wide."
		let font = UIFont.systemFont(ofSize: 17)

		// A garbage-width measurement must return zero and must not be cached.
		let negativeWidthSize = MultilineUILabelSizer.size(for: string, font: font, numberOfLines: 3, width: -88)
		#expect(negativeWidthSize.size.height == 0)

		// The same string at a real width must still wrap.
		let sized = MultilineUILabelSizer.size(for: string, font: font, numberOfLines: 3, width: 200)
		#expect(sized.numberOfLinesUsed > 1)
	}
}
