//
//  IconImage.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Core

public final class IconImage {
	
	public lazy var isDark: Bool = {
		return image.isDark()
	}()
	
	public lazy var isBright: Bool = {
		return image.isBright()
	}()
	
	public let image: RSImage
	public let isSymbol: Bool
	public let isBackgroundSupressed: Bool
	public let preferredColor: CGColor?

	public init(_ image: RSImage, isSymbol: Bool = false, isBackgroundSupressed: Bool = false, preferredColor: CGColor? = nil) {
		self.image = image
		self.isSymbol = isSymbol
		self.preferredColor = preferredColor
		self.isBackgroundSupressed = isBackgroundSupressed
	}
	
}

#if os(macOS)
	extension NSImage {
		func isDark() -> Bool {
			return self.cgImage(forProposedRect: nil, context: nil, hints: nil)?.isDark() ?? false
		}
		
		func isBright() -> Bool {
			return self.cgImage(forProposedRect: nil, context: nil, hints: nil)?.isBright() ?? false
		}
	}
#else
	extension UIImage {
		func isDark() -> Bool {
			return self.cgImage?.isDark() ?? false
		}
		
		func isBright() -> Bool {
			return self.cgImage?.isBright() ?? false
		}
	}
#endif

fileprivate enum ImageLuminanceType {
	case regular, bright, dark
}

extension CGImage {

	func isBright() -> Bool {
		guard let luminanceType = getLuminanceType() else {
			return false
		}
		return luminanceType == .bright
	}
	
	func isDark() -> Bool {
		guard let luminanceType = getLuminanceType() else {
			return false
		}
		return luminanceType == .dark
	}
	
	fileprivate func getLuminanceType() -> ImageLuminanceType? {
		
		// This has been rewritten with information from https://christianselig.com/2021/04/efficient-average-color/
		
		// First, resize the image. We do this for two reasons, 1) less pixels to deal with means faster
		// calculation and a resized image still has the "gist" of the colors, and 2) the image we're dealing
		// with may come in any of a variety of color formats (CMYK, ARGB, RGBA, etc.) which complicates things,
		// and redrawing it normalizes that into a base color format we can deal with.
		// 40x40 is a good size to resize to still preserve quite a bit of detail but not have too many pixels
		// to deal with. Aspect ratio is irrelevant for just finding average color.
		let size = CGSize(width: 40, height: 40)
		
		let width = Int(size.width)
		let height = Int(size.height)
		let totalPixels = width * height
		
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		
		// ARGB format
		let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
		
		// 8 bits for each color channel, we're doing ARGB so 32 bits (4 bytes) total, and thus if the image is n pixels wide,
		// and has 4 bytes per pixel, the total bytes per row is 4n. That gives us 2^8 = 256 color variations for each RGB channel
		// or 256 * 256 * 256 = ~16.7M color options in total. That seems like a lot, but lots of HDR movies are in 10 bit, which
		// is (2^10)^3 = 1 billion color options!
		guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
		
		// Draw our resized image
		context.draw(self, in: CGRect(origin: .zero, size: size))
		
		guard let pixelBuffer = context.data else { return nil }
		
		// Bind the pixel buffer's memory location to a pointer we can use/access
		let pointer = pixelBuffer.bindMemory(to: UInt32.self, capacity: width * height)
		
		var totalLuminance = 0.0
		
		// Column of pixels in image
		for x in 0 ..< width {
			// Row of pixels in image
			for y in 0 ..< height {
				// To get the pixel location just think of the image as a grid of pixels, but stored as one long row
				// rather than columns and rows, so for instance to map the pixel from the grid in the 15th row and 3
				// columns in to our "long row", we'd offset ourselves 15 times the width in pixels of the image, and
				// then offset by the amount of columns
				let pixel = pointer[(y * width) + x]
				
				let r = red(for: pixel)
				let g = green(for: pixel)
				let b = blue(for: pixel)
				
				let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
				
				totalLuminance += luminance
			}
		}
		
		let avgLuminance = totalLuminance / Double(totalPixels)
		if totalLuminance == 0 || avgLuminance < 40 {
			return .dark
		} else if avgLuminance > 180 {
			return .bright
		} else {
			return .regular
		}
	}
	
	private func red(for pixelData: UInt32) -> UInt8 {
		return UInt8((pixelData >> 16) & 255)
	}
	
	private func green(for pixelData: UInt32) -> UInt8 {
		return UInt8((pixelData >> 8) & 255)
	}
	
	private func blue(for pixelData: UInt32) -> UInt8 {
		return UInt8((pixelData >> 0) & 255)
	}
	
}


public enum IconSize: Int, CaseIterable {
	case small = 1
	case medium = 2
	case large = 3
	
	private static let smallDimension = CGFloat(integerLiteral: 24)
	private static let mediumDimension = CGFloat(integerLiteral: 36)
	private static let largeDimension = CGFloat(integerLiteral: 48)

	public var size: CGSize {
		switch self {
		case .small:
			return CGSize(width: IconSize.smallDimension, height: IconSize.smallDimension)
		case .medium:
			return CGSize(width: IconSize.mediumDimension, height: IconSize.mediumDimension)
		case .large:
			return CGSize(width: IconSize.largeDimension, height: IconSize.largeDimension)
		}
	}

}
