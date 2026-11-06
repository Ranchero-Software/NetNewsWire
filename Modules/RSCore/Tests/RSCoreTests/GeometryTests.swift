//
//  GeometryTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 11/5/26.
//

import CoreGraphics
import Testing
import RSCore

@Suite struct GeometryTests {

	@Test func aspectFitRectCentersALandscapeImageInAWiderRect() {
		// A large thumbnail’s rect and a 3:2 image: 180 tall, 270 wide, centered.
		let rect = CGRect(x: 20, y: 40, width: 400, height: 180)
		#expect(rect.aspectFitRect(for: CGSize(width: 1500, height: 1000)) == CGRect(x: 85, y: 40, width: 270, height: 180))
	}
}
