//
//  RSImage.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import os.log

#if os(macOS)
import AppKit
public typealias RSImage = NSImage
#endif

#if os(iOS)
import UIKit
public typealias RSImage = UIImage
#endif

nonisolated private let RSImageLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "RSImage")
nonisolated private let debugLoggingEnabled = false

nonisolated public extension RSImage {

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
	///   - imageResultBlock: The closure to call when the image has been initialized.
	static func image(with data: Data, imageResultBlock: @escaping ImageResultBlock) {
		DispatchQueue.global().async {
			let image = RSImage(data: data)
			DispatchQueue.main.async {
				imageResultBlock(image)
			}
		}
	}

	/// Create a scaled image from image data.
	///
	/// - Note: the returned image may be larger than `maxPixelSize`, but not more than `maxPixelSize * 2`.
	/// - Parameters:
	///   - data: The data object containing the image data.
	///   - maxPixelSize: The maximum dimension of the image.
	static func scaleImage(_ data: Data, maxPixelSize: Int) -> CGImage? {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
			if debugLoggingEnabled {
				RSImageLogger.debug("RSImageLogger: couldn’t create image source")
			}
			return nil
		}

		let numberOfImages = CGImageSourceGetCount(imageSource)
		if debugLoggingEnabled {
			RSImageLogger.debug("RSImageLogger: numberOfImages == \(numberOfImages, privacy: .public)")
		}
		guard numberOfImages > 0 else {
			return nil
		}

		var exactMatch: (index: Int, maxDimension: Int)? = nil
		var goodMatch: (index: Int, maxDimension: Int)? = nil
		var smallMatch: (index: Int, maxDimension: Int)? = nil

		// Single pass through all images to find the best match
		for i in 0..<numberOfImages {
			guard let cfImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil),
				  let imagePixelWidth = (cfImageProperties as NSDictionary)[kCGImagePropertyPixelWidth] as? NSNumber,
				  let imagePixelHeight = (cfImageProperties as NSDictionary)[kCGImagePropertyPixelHeight] as? NSNumber else {
				continue
			}

			let width = imagePixelWidth.intValue
			let height = imagePixelHeight.intValue
			let maxDimension = max(width, height)

			if debugLoggingEnabled {
				RSImageLogger.debug("RSImageLogger: found width \(width, privacy: .public) height \(height, privacy: .public) \(maxPixelSize, privacy: .public)")
			}

			// Skip invalid dimensions
			guard width > 0 && height > 0 else {
				continue
			}

			// Check for exact match (largest dimension equals maxPixelSize)
			if maxDimension == maxPixelSize {
				exactMatch = (i, maxDimension)
				if debugLoggingEnabled {
					RSImageLogger.debug("RSImageLogger: found exact match for maxPixelSize: \(maxPixelSize, privacy: .public)")
				}
				break // Exact match is best, stop searching
			}

			// Check for good larger match
			if maxDimension > maxPixelSize && maxDimension <= maxPixelSize * 4 {
				if let currentGoodMatch = goodMatch {
					if maxDimension < currentGoodMatch.maxDimension {
						goodMatch = (i, maxDimension) // Prefer smaller size in this range
					}
				} else {
					goodMatch = (i, maxDimension)
				}
				if debugLoggingEnabled {
					RSImageLogger.debug("RSImageLogger: found good match \(maxDimension, privacy: .public) for maxPixelSize: \(maxPixelSize, privacy: .public)")
				}
			}

			// Check for small match (smaller than maxPixelSize)
			if maxDimension < maxPixelSize {
				if let currentSmallMatch = smallMatch {
					if maxDimension > currentSmallMatch.maxDimension {
						smallMatch = (i, maxDimension) // Prefer larger size in this range
					}
				} else {
					smallMatch = (i, maxDimension)
				}
				if debugLoggingEnabled {
					RSImageLogger.debug("RSImageLogger: found small match \(maxDimension, privacy: .public) for maxPixelSize: \(maxPixelSize, privacy: .public)")
				}
			}
		}

		// Return best match in order of preference: exact > good > small
		if let match = exactMatch ?? goodMatch ?? smallMatch {
			return CGImageSourceCreateImageAtIndex(imageSource, match.index, nil)
		}

		// Fallback to creating a thumbnail
		if debugLoggingEnabled {
			RSImageLogger.debug("RSImageLogger: found no match — calling createThumbnail")
		}
		return RSImage.createThumbnail(imageSource, maxPixelSize: maxPixelSize)
	}

	/// Create a thumbnail from a CGImageSource.
	///
	/// - Parameters:
	///   - imageSource: The `CGImageSource` from which to create the thumbnail.
	///   - maxPixelSize: The maximum dimension of the resulting image.
	static func createThumbnail(_ imageSource: CGImageSource, maxPixelSize: Int) -> CGImage? {
		guard maxPixelSize > 0 else {
			return nil
		}

		let count = CGImageSourceGetCount(imageSource)
		guard count > 0 else {
			return nil
		}

		if debugLoggingEnabled {
			RSImageLogger.debug("RSImageLogger: createThumbnail image source count = \(count, privacy: .public)")
		}

		let options = [kCGImageSourceCreateThumbnailWithTransform : true,
					   kCGImageSourceCreateThumbnailFromImageIfAbsent : true,
					   kCGImageSourceThumbnailMaxPixelSize : NSNumber(value: maxPixelSize)]
		return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
	}
}
