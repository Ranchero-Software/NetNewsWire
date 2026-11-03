//
//  ThumbnailDownloaderTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 11/3/26.
//

import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Images

@MainActor @Suite struct ThumbnailDownloaderTests {

	@Test func thumbnailTooSmallIsRejected() async throws {
		let smallImageData = try #require(jpegData(width: 48, height: 48))

		await #expect {
			_ = try await ThumbnailDownloader.decodedImage(smallImageData, maxPixelSize: 512, maxPixelHeight: nil)
		} throws: { error in
			(error as? ImageDownloadError)?.rejectedPixelSize?.width == 48
		}
	}

	@Test func thumbnailIsDecodedInEXIFOrientation() async throws {
		let rotatedImageData = try #require(jpegData(width: 400, height: 200, orientation: .right))

		let decodedImage = try await ThumbnailDownloader.decodedImage(rotatedImageData, maxPixelSize: 512, maxPixelHeight: nil)
		#expect(decodedImage.image.size == CGSize(width: 200, height: 400))
	}

	@Test func largestFrameOfMultiImageFileIsDecoded() async throws {
		let imageData = try #require(tiffData(frameSizes: [(width: 48, height: 48), (width: 400, height: 200)]))

		let decodedImage = try await ThumbnailDownloader.decodedImage(imageData, maxPixelSize: 512, maxPixelHeight: nil)
		#expect(decodedImage.image.size == CGSize(width: 400, height: 200))
	}

	@Test func largeThumbnailIsDecodedToItsDisplayedHeight() async throws {
		let landscapeImageData = try #require(jpegData(width: 1500, height: 1000))
		let landscapeImage = try await ThumbnailDownloader.decodedImage(landscapeImageData, maxPixelSize: 1200, maxPixelHeight: 360)
		#expect(landscapeImage.image.size == CGSize(width: 540, height: 360))

		// Stored taller than wide, displayed wider than tall.
		let rotatedImageData = try #require(jpegData(width: 1000, height: 1500, orientation: .right))
		let rotatedImage = try await ThumbnailDownloader.decodedImage(rotatedImageData, maxPixelSize: 1200, maxPixelHeight: 360)
		#expect(rotatedImage.image.size == CGSize(width: 540, height: 360))

		let wideImageData = try #require(jpegData(width: 2000, height: 500))
		let wideImage = try await ThumbnailDownloader.decodedImage(wideImageData, maxPixelSize: 1200, maxPixelHeight: 360)
		#expect(wideImage.image.size == CGSize(width: 1200, height: 300))
	}
}

// MARK: - Helpers

private func makeImage(width: Int, height: Int) -> CGImage? {
	guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
		return nil
	}
	context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
	context.fill(CGRect(x: 0, y: 0, width: width, height: height))
	return context.makeImage()
}

private func tiffData(frameSizes: [(width: Int, height: Int)]) -> Data? {
	guard let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, UTType.tiff.identifier as CFString, frameSizes.count, nil) else {
		return nil
	}
	for frameSize in frameSizes {
		guard let cgImage = makeImage(width: frameSize.width, height: frameSize.height) else {
			return nil
		}
		CGImageDestinationAddImage(destination, cgImage, nil)
	}
	guard CGImageDestinationFinalize(destination) else {
		return nil
	}
	return mutableData as Data
}

private func jpegData(width: Int, height: Int, orientation: CGImagePropertyOrientation = .up) -> Data? {
	guard let cgImage = makeImage(width: width, height: height), let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
		return nil
	}
	let properties = [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
	CGImageDestinationAddImage(destination, cgImage, properties)
	guard CGImageDestinationFinalize(destination) else {
		return nil
	}
	return mutableData as Data
}
