//
//  ScaledImageDataTests.swift
//  RSCore
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import RSCore

@Suite struct ScaledImageDataTests {

	@Test func jpegFormatResizesOpaqueImageToJPEGAndTransparentImageToPNG() throws {
		let opaqueData = try #require(pngData(width: 2000, height: 1000, alphaInfo: .noneSkipLast))
		let transparentData = try #require(pngData(width: 2000, height: 1000, alphaInfo: .premultipliedLast))

		let scaledOpaqueData = try #require(RSImage.scaledImageData(opaqueData, maxPixelSize: 512, format: .jpeg(compressionQuality: 0.8)))
		let scaledTransparentData = try #require(RSImage.scaledImageData(transparentData, maxPixelSize: 512, format: .jpeg(compressionQuality: 0.8)))

		#expect(imageType(scaledOpaqueData) == UTType.jpeg.identifier)
		#expect(imageType(scaledTransparentData) == UTType.png.identifier)
		#expect(RSImage.largestFramePixelSize(scaledOpaqueData)?.width == 512)
		#expect(RSImage.largestFramePixelSize(scaledOpaqueData)?.height == 256)
	}
}

// MARK: - Helpers

private func pngData(width: Int, height: Int, alphaInfo: CGImageAlphaInfo) -> Data? {
	guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue) else {
		return nil
	}
	context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
	context.fill(CGRect(x: 0, y: 0, width: width, height: height))
	guard let cgImage = context.makeImage(), let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
		return nil
	}
	CGImageDestinationAddImage(destination, cgImage, nil)
	guard CGImageDestinationFinalize(destination) else {
		return nil
	}
	return mutableData as Data
}

private func imageType(_ data: Data) -> String? {
	guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
		return nil
	}
	return CGImageSourceGetType(imageSource) as String?
}
