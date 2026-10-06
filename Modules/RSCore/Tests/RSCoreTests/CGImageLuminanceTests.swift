//
//  CGImageLuminanceTests.swift
//  RSCore
//
//  Created by Brent Simmons on 6/26/26.
//

import Testing
import CoreGraphics
@testable import RSCore

// calculateLuminanceType classifies an image as .bright, .dark, or .regular so the UI can
// decide whether to draw a background behind a feed icon.

@Suite struct CGImageLuminanceTests {

	@Test func whiteImageWithTransparencyIsBright() {
		// Half white-opaque, half transparent. The transparent half must be ignored
		// so the result is .bright.
		let image = makeImage(size: 100, opaqueFraction: 0.5, fillWhite: true)
		#expect(image.calculateLuminanceType() == .bright)
	}

	@Test func fullyWhiteOpaqueIsBright() {
		let image = makeImage(size: 100, opaqueFraction: 1.0, fillWhite: true)
		#expect(image.calculateLuminanceType() == .bright)
	}

	@Test func fullyBlackOpaqueIsDark() {
		let image = makeImage(size: 100, opaqueFraction: 1.0, fillWhite: false)
		#expect(image.calculateLuminanceType() == .dark)
	}

	@Test func midGrayOpaqueIsRegular() {
		let image = makeGrayImage(size: 100, gray: 0.5)
		#expect(image.calculateLuminanceType() == .regular)
	}

	@Test func fullyTransparentIsRegular() {
		let image = makeImage(size: 100, opaqueFraction: 0.0, fillWhite: true)
		#expect(image.calculateLuminanceType() == .regular)
	}
}

private extension CGImageLuminanceTests {

	// Builds an image with an opaque (white or black) region covering the bottom
	// `opaqueFraction` of rows. The remainder is left transparent.
	func makeImage(size: Int, opaqueFraction: CGFloat, fillWhite: Bool) -> CGImage {
		let context = makeContext(size: size)
		let opaqueHeight = CGFloat(size) * opaqueFraction
		if opaqueHeight > 0 {
			let value: CGFloat = fillWhite ? 1.0 : 0.0
			context.setFillColor(red: value, green: value, blue: value, alpha: 1.0)
			context.fill(CGRect(x: 0, y: 0, width: CGFloat(size), height: opaqueHeight))
		}
		return context.makeImage()!
	}

	// Builds a fully opaque image of a single gray value.
	func makeGrayImage(size: Int, gray: CGFloat) -> CGImage {
		let context = makeContext(size: size)
		context.setFillColor(red: gray, green: gray, blue: gray, alpha: 1.0)
		context.fill(CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size)))
		return context.makeImage()!
	}

	func makeContext(size: Int) -> CGContext {
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
		let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: colorSpace, bitmapInfo: bitmapInfo)!
		context.clear(CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size)))
		return context
	}
}
