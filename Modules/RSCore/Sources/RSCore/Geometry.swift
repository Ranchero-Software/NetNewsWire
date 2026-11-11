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

	/// The largest rectangle with `size`’s aspect ratio that fits in this one, centered, in whole points.
	/// This rectangle when `size` has no width or height.
	func aspectFitRect(for size: CGSize) -> CGRect {
		guard size.width > 0.0, size.height > 0.0 else {
			return self
		}
		let scale = Swift.min(width / size.width, height / size.height)
		let fittedWidth = (size.width * scale).rounded()
		let fittedHeight = (size.height * scale).rounded()
		return CGRect(x: minX + floor((width - fittedWidth) / 2.0), y: minY + floor((height - fittedHeight) / 2.0), width: fittedWidth, height: fittedHeight)
	}
}

public extension Array where Element == CGRect {
	func maxY() -> CGFloat {
		var y: CGFloat = 0.0
		for r in self {
			y = Swift.max(y, r.maxY)
		}
		return y
	}
}
