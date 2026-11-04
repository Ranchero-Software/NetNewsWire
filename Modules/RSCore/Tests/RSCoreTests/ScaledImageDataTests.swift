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

	@Test func largeImageIsResizedToPNG() throws {
		let data = try #require(pngData(width: 2000, height: 1000))

		let scaledData = try #require(RSImage.scaledImageData(data, maxPixelSize: 512))

		#expect(imageType(scaledData) == UTType.png.identifier)
		#expect(RSImage.largestFramePixelSize(scaledData)?.width == 512)
		#expect(RSImage.largestFramePixelSize(scaledData)?.height == 256)
	}

	@Test func jpegIsScaledFromFullImageNotEmbeddedThumbnail() throws {
		let data = try #require(imageData(width: 2000, height: 1500, type: UTType.jpeg, embedsThumbnail: true))

		let scaledData = try #require(RSImage.scaledImageData(data, maxPixelSize: 288))

		#expect(RSImage.largestFramePixelSize(scaledData)?.width == 288)
		#expect(RSImage.largestFramePixelSize(scaledData)?.height == 216)
	}

#if os(macOS)
	@Test func svgIsRasterizedToPNG() throws {
		let scaledData = try #require(RSImage.scaledImageData(svgData, maxPixelSize: 64))

		#expect(imageType(scaledData) == UTType.png.identifier)
		#expect(RSImage.largestFramePixelSize(scaledData)?.width == 64)
		#expect(RSImage.largestFramePixelSize(scaledData)?.height == 32)
	}

	@Test func svgRasterizingIsDeterministic() throws {
		let scaledData = try #require(RSImage.scaledImageData(svgData, maxPixelSize: 64))
		let scaledAgainData = try #require(RSImage.scaledImageData(svgData, maxPixelSize: 64))

		#expect(scaledData == scaledAgainData)
	}
#endif
}

// MARK: - Helpers

private let svgData = Data(##"<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 200 100"><rect width="200" height="100" fill="#336699"/><circle cx="100" cy="50" r="40" fill="#ffcc00"/></svg>"##.utf8)

private func pngData(width: Int, height: Int) -> Data? {
	imageData(width: width, height: height, type: UTType.png, embedsThumbnail: false)
}

private func imageData(width: Int, height: Int, type: UTType, embedsThumbnail: Bool) -> Data? {
	guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
		return nil
	}
	context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
	context.fill(CGRect(x: 0, y: 0, width: width, height: height))
	guard let cgImage = context.makeImage(), let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, type.identifier as CFString, 1, nil) else {
		return nil
	}
	let properties = [kCGImageDestinationEmbedThumbnail: embedsThumbnail] as CFDictionary
	CGImageDestinationAddImage(destination, cgImage, properties)
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
