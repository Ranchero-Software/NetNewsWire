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
import RSCore
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

	@Test func smallThumbnailIsCroppedFromTheBottomOfATallImage() async throws {
		// Top half red, bottom half blue: the square is the top half, so it’s red. A centered square would be blue near its bottom.
		// The bottom row itself is blended with the first blue row by scaling, so the pixel checked is a little above it.
		let portraitImageData = try #require(jpegData(width: 300, height: 600, topHalfRed: true))
		let decodedImage = try await ThumbnailDownloader.decodedSquareImage(portraitImageData, pixelSize: 256)
		#expect(decodedImage.image.size == CGSize(width: 256, height: 256))

		let nearBottomPixel = try #require(pixel(decodedImage.image, x: 128, yFromTop: 224))
		#expect(nearBottomPixel.red > 200 && nearBottomPixel.blue < 50)
	}
}

// MARK: - Helpers

private func makeImage(width: Int, height: Int, topHalfRed: Bool = false) -> CGImage? {
	guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
		return nil
	}
	if topHalfRed {
		context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
		context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
		context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
		context.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
	} else {
		context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
		context.fill(CGRect(x: 0, y: 0, width: width, height: height))
	}
	return context.makeImage()
}

private func pixel(_ image: RSImage, x: Int, yFromTop: Int) -> (red: UInt8, blue: UInt8)? {
	#if os(macOS)
	guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
		return nil
	}
	#else
	guard let cgImage = image.cgImage else {
		return nil
	}
	#endif
	var bytes = [UInt8](repeating: 0, count: 4)
	let didDraw = bytes.withUnsafeMutableBytes { buffer -> Bool in
		guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
			return false
		}
		// Places the requested pixel at the 1×1 context’s origin, which is at the bottom left.
		context.draw(cgImage, in: CGRect(x: -x, y: yFromTop - (cgImage.height - 1), width: cgImage.width, height: cgImage.height))
		return true
	}
	guard didDraw else {
		return nil
	}
	return (red: bytes[0], blue: bytes[2])
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

private func jpegData(width: Int, height: Int, orientation: CGImagePropertyOrientation = .up, topHalfRed: Bool = false) -> Data? {
	guard let cgImage = makeImage(width: width, height: height, topHalfRed: topHalfRed), let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
		return nil
	}
	let properties = [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
	CGImageDestinationAddImage(destination, cgImage, properties)
	guard CGImageDestinationFinalize(destination) else {
		return nil
	}
	return mutableData as Data
}
