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

import RSCore

extension RSImage {
	public static let maxIconPixelSize = Int(ceil(48.0 * RSScreen.maxScreenScale))
}

public final class IconImage: @unchecked Sendable {
	public let image: RSImage
	public let isSymbol: Bool
	public let isBackgroundSuppressed: Bool
	public let preferredColor: CGColor?

	private lazy var luminanceType: ImageLuminanceType = {
		#if os(macOS)
		guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .regular }
		#else
		guard let cgImage = image.cgImage else { return .regular }
		#endif
		return cgImage.calculateLuminanceType() ?? .regular
	}()

	public var isDark: Bool {
		luminanceType == .dark
	}

	public var isBright: Bool {
		luminanceType == .bright
	}

	public init(_ image: RSImage, isSymbol: Bool = false, isBackgroundSuppressed: Bool = false, preferredColor: CGColor? = nil) {
		self.image = image
		self.isSymbol = isSymbol
		self.preferredColor = preferredColor
		self.isBackgroundSuppressed = isBackgroundSuppressed
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
