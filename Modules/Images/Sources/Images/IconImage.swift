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
	private static let luminanceQueue = DispatchQueue(label: "com.ranchero.NetNewsWire.IconImage.luminance", qos: .utility, attributes: .concurrent)

	public var isDark: Bool {
		luminanceType == .dark
	}

	public var isBright: Bool {
		luminanceType == .bright
	}

	public init(_ image: RSImage, isSymbol: Bool = false, isBackgroundSuppressed: Bool = false, preferredColor: RSColor? = nil) {
		self.image = image
		self.isSymbol = isSymbol
		self.preferredColor = preferredColor
		self.isBackgroundSuppressed = isBackgroundSuppressed
		self.cachedLuminanceType = Mutex(nil)
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
