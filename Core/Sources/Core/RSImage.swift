//
//  RSImage.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

#if os(macOS)
import AppKit
public typealias RSImage = NSImage
#endif

#if os(iOS)
import UIKit
public typealias RSImage = UIImage
#endif

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

	/// Returns a data representation of the image.
	///
	/// The resultant data is TIFF data on macOS, and PNG data on iOS.
	/// - Returns: Data representing the image.
	func dataRepresentation() -> Data? {
		#if os(macOS)
			return tiffRepresentation
		#else
			return pngData()
		#endif
	}

	static func image(with data: Data) async -> RSImage? {

		RSImage(data: data)
	}

	/// Create a scaled image from image data.
	///
	/// - Note: the returned image may be larger than `maxPixelSize`, but not more than `maxPixelSize * 2`.
	/// - Parameters:
	///   - data: The data object containing the image data.
	///   - maxPixelSize: The maximum dimension of the image.
	static func scaleImage(_ data: Data, maxPixelSize: Int) -> CGImage? {
		
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
			return nil
		}
		
		let numberOfImages = CGImageSourceGetCount(imageSource)

		// If the image size matches exactly, then return it.
		for i in 0..<numberOfImages {

			guard let cfImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) else {
				continue
			}

			let imageProperties = cfImageProperties as NSDictionary

			guard let imagePixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? NSNumber else {
				continue
			}
			if imagePixelWidth.intValue != maxPixelSize {
				continue
			}
			
			guard let imagePixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? NSNumber else {
				continue
			}
			if imagePixelHeight.intValue != maxPixelSize {
				continue
			}
			
			return CGImageSourceCreateImageAtIndex(imageSource, i, nil)
		}

		// If image height > maxPixelSize, but <= maxPixelSize * 2, then return it.
		for i in 0..<numberOfImages {

			guard let cfImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) else {
				continue
			}

			let imageProperties = cfImageProperties as NSDictionary

			guard let imagePixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? NSNumber else {
				continue
			}
			if imagePixelWidth.intValue > maxPixelSize * 2 || imagePixelWidth.intValue < maxPixelSize {
				continue
			}

			guard let imagePixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? NSNumber else {
				continue
			}
			if imagePixelHeight.intValue > maxPixelSize * 2 || imagePixelHeight.intValue < maxPixelSize {
				continue
			}

			return CGImageSourceCreateImageAtIndex(imageSource, i, nil)
		}


		// If the image data contains a smaller image than the max size, just return it.
		for i in 0..<numberOfImages {
			
			guard let cfImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) else {
				continue
			}
			
			let imageProperties = cfImageProperties as NSDictionary
			
			guard let imagePixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? NSNumber else {
				continue
			}
			if imagePixelWidth.intValue < 1 || imagePixelWidth.intValue > maxPixelSize {
				continue
			}
			
			guard let imagePixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? NSNumber else {
				continue
			}
			if imagePixelHeight.intValue > 0 && imagePixelHeight.intValue <= maxPixelSize {
				if let image = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
					return image
				}
			}
		}
		
		return RSImage.createThumbnail(imageSource, maxPixelSize: maxPixelSize)
		
	}

	/// Create a thumbnail from a CGImageSource.
	///
	/// - Parameters:
	///   - imageSource: The `CGImageSource` from which to create the thumbnail.
	///   - maxPixelSize: The maximum dimension of the resulting image.
	static func createThumbnail(_ imageSource: CGImageSource, maxPixelSize: Int) -> CGImage? {
		let options = [kCGImageSourceCreateThumbnailWithTransform : true,
					   kCGImageSourceCreateThumbnailFromImageIfAbsent : true,
					   kCGImageSourceThumbnailMaxPixelSize : NSNumber(value: maxPixelSize)]
		return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
	}
	
}
