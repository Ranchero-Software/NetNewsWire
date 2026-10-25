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
public typealias RSColor = NSColor
#endif

#if os(iOS)
import UIKit
public typealias RSImage = UIImage
public typealias RSColor = UIColor
#endif

private let RSImageLogger = Logger(subsystem: Logger.nnwSubsystem, category: "RSImage")

public enum ScaledImageFormat: Sendable {
	case png
	/// Images with an alpha channel are encoded as PNG, since JPEG can’t store transparency.
	case jpeg(compressionQuality: Double)
}

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

	/// Pixel dimensions of the largest frame, read from the image header without decoding.
	/// Returns nil if the data can't be read as an image.
	static func largestFramePixelSize(_ data: Data) -> (width: Int, height: Int)? {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let largestFrame = largestFrame(in: imageSource) else {
			return nil
		}
		return (width: largestFrame.width, height: largestFrame.height)
	}

	/// Scales image data down to maxPixelSize and returns the result encoded in `format`.
	/// If the image is a single frame already at or below maxPixelSize, returns
	/// the original data unchanged. For multi-image sources (like ICO), extracts
	/// the largest frame. Returns nil if the data can't be decoded as an image.
	static func scaledImageData(_ data: Data, maxPixelSize: Int, format: ScaledImageFormat = .png) -> Data? {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
			return nil
		}

		let count = CGImageSourceGetCount(imageSource)
		guard let largestFrame = largestFrame(in: imageSource) else {
			return nil
		}
		let largestIndex = largestFrame.index
		let largestWidth = largestFrame.width
		let largestHeight = largestFrame.height
		let largestMaxDimension = max(largestWidth, largestHeight)

		let needsResize = largestMaxDimension > maxPixelSize
		let isMultiImage = count > 1

		// Single-frame image already small enough — return original data as-is.
		if !needsResize && !isMultiImage {
			RSImageLogger.info("Image already small enough: \(largestWidth, privacy: .public)x\(largestHeight, privacy: .public) <= \(maxPixelSize, privacy: .public)px max")
			return data
		}

		// Either too large or multi-image — extract/resize to a single image.
		// Always use CreateThumbnailAtIndex rather than CreateImageAtIndex,
		// because the latter mishandles indexed-color ICO files (produces
		// grayscale with a nil color space instead of correct RGB).
		let thumbnailSize = needsResize ? maxPixelSize : largestMaxDimension
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
			kCGImageSourceThumbnailMaxPixelSize: thumbnailSize
		]
		let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, largestIndex, options as CFDictionary)

		guard let cgImage else {
			return nil
		}

		let (type, destinationProperties) = destinationTypeAndProperties(format, cgImage)
		guard let mutableData = CFDataCreateMutable(nil, 0),
			  let destination = CGImageDestinationCreateWithData(mutableData, type.identifier as CFString, 1, nil) else {
			return nil
		}
		CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary?)
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

private extension RSImage {

	static func largestFrame(in imageSource: CGImageSource) -> (index: Int, width: Int, height: Int)? {
		var largest: (index: Int, width: Int, height: Int)?

		for i in 0..<CGImageSourceGetCount(imageSource) {
			guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as NSDictionary?,
				  let width = properties[kCGImagePropertyPixelWidth] as? Int,
				  let height = properties[kCGImagePropertyPixelHeight] as? Int,
				  width > 0, height > 0 else {
				continue
			}
			if let largest, max(largest.width, largest.height) >= max(width, height) {
				continue
			}
			largest = (index: i, width: width, height: height)
		}

		return largest
	}

	static func destinationTypeAndProperties(_ format: ScaledImageFormat, _ cgImage: CGImage) -> (UTType, [CFString: Any]?) {
		switch format {
		case .png:
			return (.png, nil)
		case .jpeg(let compressionQuality):
			let isOpaque = [.none, .noneSkipFirst, .noneSkipLast].contains(cgImage.alphaInfo)
			guard isOpaque else {
				return (.png, nil)
			}
			return (.jpeg, [kCGImageDestinationLossyCompressionQuality: compressionQuality])
		}
	}
}
