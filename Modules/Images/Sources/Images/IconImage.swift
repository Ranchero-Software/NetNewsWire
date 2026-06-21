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
import os
import RSCore

extension RSImage {
	public static let maxIconPixelSize = Int(ceil(48.0 * RSScreen.maxScreenScale))
}

public final class IconImage: @unchecked Sendable {
	public let image: RSImage
	public let isSymbol: Bool
	public let isBackgroundSuppressed: Bool
	public let preferredColor: RSColor?

	private let cachedLuminanceType = OSAllocatedUnfairLock<ImageLuminanceType?>(initialState: nil)
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
		if !isBackgroundSuppressed && Thread.isMainThread {
			preloadLuminanceType()
		}
	}
}

private extension IconImage {

	var luminanceType: ImageLuminanceType {
		if let luminanceType = cachedLuminanceType.withLock({ $0 }) {
			return luminanceType
		}

		let luminanceType = IconImage.luminanceType(for: luminanceCGImage())
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

		let cgImage = luminanceCGImage()
		IconImage.luminanceQueue.async {
			let luminanceType = IconImage.luminanceType(for: cgImage)
			self.cachedLuminanceType.withLock {
				if $0 == nil {
					$0 = luminanceType
				}
			}
		}
	}

	func luminanceCGImage() -> CGImage? {
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
