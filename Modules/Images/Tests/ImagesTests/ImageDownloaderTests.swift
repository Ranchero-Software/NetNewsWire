//
//  ImageDownloaderTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Images

@Suite struct ImageDownloaderTests {

	@Test func thumbnailTooSmallIsRejected() async throws {
		let configuration = ImageDownloader.Configuration(cacheFolderName: "Test", maxPixelSize: 512, format: .jpeg(compressionQuality: 0.8), memoryCacheByteLimit: 0, requiresSignificantDimensions: true, downloadLimiter: nil)
		let smallImageData = try #require(pngData(width: 72, height: 72))

		await #expect {
			_ = try await ImageDownloader.scaledImageData(smallImageData, statusCode: 200, configuration: configuration)
		} throws: { error in
			(error as? ImageDownloadError)?.rejectedPixelSize?.width == 72
		}
	}
}

// MARK: - Helpers

private func pngData(width: Int, height: Int) -> Data? {
	guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
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
