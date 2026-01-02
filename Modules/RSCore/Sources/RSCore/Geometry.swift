//
//  Geometry.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-01.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension CGRect {

	/// Centers a rectangle vertically in another rectangle.
	///
	/// - Parameter containerRect: The rectangle in which to be centered.
	/// - Returns: A new rectangle, cenetered vertically in `containerRect`,
	///   with the same size as the source rectangle.
	func centeredVertically(in containerRect: CGRect) -> CGRect {
		var r = self
		r.origin.y = containerRect.midY - (r.height / 2.0)
		r = r.integral
		r.size = self.size
		return r
	}

	/// Centers a rectangle horizontally in another rectangle.
	///
	/// - Parameter containerRect: The rectangle in which to be centered.
	/// - Returns: A new rectangle, cenetered horizontally in `containerRect`,
	///   with the same size as the source rectangle.
	func centeredHorizontally(in containerRect: CGRect) -> CGRect {
		var r = self
		r.origin.x = containerRect.midX - (r.width / 2.0)
		r = r.integral
		r.size = self.size
		return r
	}

	/// Centers a rectangle in another rectangle.
	/// 
	/// - Parameter containerRect: The rectangle in which to be centered.
	/// - Returns: A new rectangle, cenetered both horizontally and vertically
	///   in `containerRect`, with the same size as the source rectangle.
	func centered(in containerRect: CGRect) -> CGRect {
		self.centeredHorizontally(in: self.centeredVertically(in: containerRect))
	}
}

public extension Array where Element == CGRect {

	func maxY() -> CGFloat {
		var y: CGFloat = 0.0
		self.forEach { y = Swift.max(y, $0.maxY) }
		return y
	}
}
