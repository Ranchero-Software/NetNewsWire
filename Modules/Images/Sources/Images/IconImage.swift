//
//  IconImage.swift
//  Images
//
//  Created by Maurice Parker on 11/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Synchronization
import RSCore

extension RSImage {
	public static let maxIconPixelSize = Int(ceil(48.0 * RSScreen.maxScreenScale))
}

public final class IconImage: @unchecked Sendable {
	public let image: RSImage
	public let isSymbol: Bool
	public let isBackgroundSuppressed: Bool
	public let preferredColor: RSColor?

	private let cachedLuminanceType: Mutex<ImageLuminanceType?>
	private let cachedGrayscaleIconImage: Mutex<IconImage?>
	private static let luminanceQueue = DispatchQueue(label: "com.ranchero.NetNewsWire.IconImage.luminance", qos: .utility, attributes: .concurrent)

	public var isDark: Bool {
		luminanceType == .dark
	}

	public var isBright: Bool {
		luminanceType == .bright
	}

	/// This icon without color: bitmaps converted to grayscale, symbols tinted gray.
	public var grayscaleIconImage: IconImage {
		if let grayscaleIconImage = cachedGrayscaleIconImage.withLock({ $0 }) {
			return grayscaleIconImage
		}
		let grayscaleIconImage = makeGrayscaleIconImage()
		return cachedGrayscaleIconImage.withLock {
			if let existingIconImage = $0 {
				return existingIconImage
			}
			$0 = grayscaleIconImage
			return grayscaleIconImage
		}
	}

	public init(_ image: RSImage, isSymbol: Bool = false, isBackgroundSuppressed: Bool = false, preferredColor: RSColor? = nil) {
		self.image = image
		self.isSymbol = isSymbol
		self.preferredColor = preferredColor
		self.isBackgroundSuppressed = isBackgroundSuppressed
		self.cachedLuminanceType = Mutex(nil)
		self.cachedGrayscaleIconImage = Mutex(nil)
		if !isBackgroundSuppressed && Thread.isMainThread {
			preloadLuminanceType()
		}
	}

	private init(_ image: RSImage, luminanceType: ImageLuminanceType) {
		self.image = image
		self.isSymbol = false
		self.preferredColor = nil
		self.isBackgroundSuppressed = false
		self.cachedLuminanceType = Mutex(luminanceType)
		self.cachedGrayscaleIconImage = Mutex(nil)
	}

	/// Decodes the image and computes its luminance off the main thread, so neither happens when a view first shows it.
	@concurrent public static func decodedIconImage(_ data: Data) async -> IconImage? {
		guard let image = RSImage.decodedImage(data: data) else {
			return nil
		}
		let luminanceType = Self.luminanceType(for: Self.cgImage(of: image))
		return IconImage(image, luminanceType: luminanceType)
	}
}

private extension IconImage {

	var luminanceType: ImageLuminanceType {
		if let luminanceType = cachedLuminanceType.withLock({ $0 }) {
			return luminanceType
		}

		let luminanceType = IconImage.luminanceType(for: IconImage.cgImage(of: image))
		cachedLuminanceType.withLock {
			if $0 == nil {
				$0 = luminanceType
			}
		}
		return luminanceType
	}

	// Compute luminance on a background queue.
	func preloadLuminanceType() {
		if cachedLuminanceType.withLock({ $0 != nil }) {
			return
		}

		let cgImage = IconImage.cgImage(of: image)
		IconImage.luminanceQueue.async {
			let luminanceType = IconImage.luminanceType(for: cgImage)
			self.cachedLuminanceType.withLock {
				if $0 == nil {
					$0 = luminanceType
				}
			}
		}
	}

	func makeGrayscaleIconImage() -> IconImage {
		if isSymbol {
			return IconImage(image, isSymbol: true, isBackgroundSuppressed: isBackgroundSuppressed, preferredColor: IconImage.grayscaleSymbolColor)
		}
		guard let cgImage = IconImage.cgImage(of: image), let grayscaleCGImage = IconImage.grayscaleCGImage(cgImage) else {
			return self
		}
		#if os(macOS)
		let grayscaleImage = NSImage(cgImage: grayscaleCGImage, size: image.size)
		#else
		let grayscaleImage = UIImage(cgImage: grayscaleCGImage, scale: image.scale, orientation: image.imageOrientation)
		#endif
		return IconImage(grayscaleImage, isBackgroundSuppressed: isBackgroundSuppressed)
	}

	/// Draws into an RGBA buffer and sets each pixel’s red, green, and blue to its luminance, keeping alpha.
	static func grayscaleCGImage(_ cgImage: CGImage) -> CGImage? {
		let width = cgImage.width
		let height = cgImage.height
		guard width > 0, height > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
			return nil
		}
		let bytesPerPixel = 4
		let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
		guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * bytesPerPixel, space: colorSpace, bitmapInfo: bitmapInfo) else {
			return nil
		}
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		guard let data = context.data else {
			return nil
		}

		// Rec. 709 luma weights. Premultiplied channels stay valid because the weights sum to 1.
		let redWeight = 0.2126
		let greenWeight = 0.7152
		let blueWeight = 0.0722

		let pixels = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
		for y in 0..<height {
			let row = pixels + y * context.bytesPerRow
			for x in 0..<width {
				let pixel = row + x * bytesPerPixel
				let luminance = redWeight * Double(pixel[0]) + greenWeight * Double(pixel[1]) + blueWeight * Double(pixel[2])
				let gray = UInt8(min(luminance.rounded(), Double(pixel[3])))
				pixel[0] = gray
				pixel[1] = gray
				pixel[2] = gray
			}
		}
		return context.makeImage()
	}

	static var grayscaleSymbolColor: RSColor {
		#if os(macOS)
		NSColor.secondaryLabelColor
		#else
		UIColor.secondaryLabel
		#endif
	}

	static func cgImage(of image: RSImage) -> CGImage? {
		#if os(macOS)
		image.cgImage(forProposedRect: nil, context: nil, hints: nil)
		#else
		image.cgImage
		#endif
	}

	static func luminanceType(for cgImage: CGImage?) -> ImageLuminanceType {
		guard let cgImage else {
			return .regular
		}
		let luminanceType = cgImage.calculateLuminanceType() ?? .regular
		return luminanceType
	}
}

public enum IconSize: Int, CaseIterable, Sendable {
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
