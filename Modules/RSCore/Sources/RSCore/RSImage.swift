//
//  RSImage.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers
import os

#if os(macOS)
import AppKit
public typealias RSImage = NSImage
#endif

#if os(iOS)
import UIKit
public typealias RSImage = UIImage
#endif

private let RSImageLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "RSImage")

public extension RSImage {

	/// Create a colored image from the source image using a specified color.
	///
	/// - Parameter color: The color with which to fill the mask image.
	/// - Returns: A new masked image.
	func maskWithColor(color: CGColor) -> RSImage? {

		#if os(macOS)
		guard let maskImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
		#else
		guard let maskImage = cgImage else { return nil }
		#endif

		let width = size.width
		let height = size.height
		let bounds = CGRect(x: 0, y: 0, width: width, height: height)

		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
		let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!

		context.clip(to: bounds, mask: maskImage)
		context.setFillColor(color)
		context.fill(bounds)

		if let cgImage = context.makeImage() {
			#if os(macOS)
			let coloredImage = RSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
			#else
			let coloredImage = RSImage(cgImage: cgImage)
			#endif
			return coloredImage
		} else {
			return nil
		}

	}

	#if os(iOS)
	/// Tint an image.
	///
	/// - Parameter color: The color to use to tint the image.
	/// - Returns: The tinted image.
	@MainActor func tinted(color: UIColor) -> UIImage? {
		let image = withRenderingMode(.alwaysTemplate)
		let imageView = UIImageView(image: image)
		imageView.tintColor = color

		UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
		if let context = UIGraphicsGetCurrentContext() {
			imageView.layer.render(in: context)
			let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			return tintedImage
		} else {
			return self
		}
	}
	#endif

#if os(macOS)
	/// Returns data as PNG. May be nil in some circumstances.
	func pngData() -> Data? {
		guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			return nil
		}
		let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
		return bitmapRep.representation(using: .png, properties: [:])
	}
#endif

	/// Returns a data representation of the image.
	/// - Returns: Image data. Normally PNG, though in rare cases it might TIFF on macOS.
	func dataRepresentation() -> Data? {
#if os(macOS)
		pngData() ?? tiffRepresentation
#else
		return pngData()
#endif
	}

	/// Asynchronously initializes an image from data.
	///
	/// - Parameters:
	///   - data: The data object containing the image data.
	static func image(data: Data) async -> RSImage? {
		await withCheckedContinuation { continuation in
			RSImage.image(with: data) { image in
				continuation.resume(returning: image)
			}
		}
	}

	/// Asynchronously initializes an image from data.
	///
	/// - Parameters:
	///   - data: The data object containing the image data.
	///   - imageResultBlock: The closure to call when the image has been initialized.
	static func image(with data: Data, imageResultBlock: @escaping ImageResultBlock) {
		DispatchQueue.global().async {
			let image = RSImage(data: data)
			DispatchQueue.main.async {
				imageResultBlock(image)
			}
		}
	}

	/// Scales image data down to maxPixelSize and returns the result as PNG Data.
	/// If the image is a single frame already at or below maxPixelSize, returns
	/// the original data unchanged. For multi-image sources (like ICO), extracts
	/// the largest frame. Returns nil if the data can't be decoded as an image.
	static func scaledImageData(_ data: Data, maxPixelSize: Int) -> Data? {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
			return nil
		}

		let count = CGImageSourceGetCount(imageSource)
		guard count > 0 else {
			return nil
		}

		// Find the largest frame in the image source.
		var largestIndex = 0
		var largestWidth = 0
		var largestHeight = 0
		var largestMaxDimension = 0

		for i in 0..<count {
			guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as NSDictionary?,
				  let width = properties[kCGImagePropertyPixelWidth] as? Int,
				  let height = properties[kCGImagePropertyPixelHeight] as? Int else {
				continue
			}
			let maxDimension = max(width, height)
			if maxDimension > largestMaxDimension {
				largestIndex = i
				largestWidth = width
				largestHeight = height
				largestMaxDimension = maxDimension
			}
		}

		guard largestMaxDimension > 0 else {
			return nil
		}

		let needsResize = largestMaxDimension > maxPixelSize
		let isMultiImage = count > 1

		// Single-frame image already small enough — return original data as-is.
		if !needsResize && !isMultiImage {
			RSImageLogger.info("Image already small enough: \(largestWidth, privacy: .public)x\(largestHeight, privacy: .public) <= \(maxPixelSize, privacy: .public)px max")
			return data
		}

		// Either too large or multi-image — extract/resize to a single PNG.
		let cgImage: CGImage?
		if needsResize {
			let options: [CFString: Any] = [
				kCGImageSourceCreateThumbnailWithTransform: true,
				kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
				kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
			]
			cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, largestIndex, options as CFDictionary)
		} else {
			cgImage = CGImageSourceCreateImageAtIndex(imageSource, largestIndex, nil)
		}

		guard let cgImage else {
			return nil
		}

		guard let mutableData = CFDataCreateMutable(nil, 0),
			  let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
			return nil
		}
		CGImageDestinationAddImage(destination, cgImage, nil)
		guard CGImageDestinationFinalize(destination) else {
			return nil
		}

		if needsResize {
			RSImageLogger.info("Resized image from \(largestWidth, privacy: .public)x\(largestHeight, privacy: .public) to \(cgImage.width, privacy: .public)x\(cgImage.height, privacy: .public)")
		} else {
			RSImageLogger.info("Extracted largest frame (\(largestWidth, privacy: .public)x\(largestHeight, privacy: .public)) from multi-image source (\(count, privacy: .public) frames)")
		}

		return mutableData as Data
	}
}
