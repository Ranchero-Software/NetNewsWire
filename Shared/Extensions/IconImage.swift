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

import RSCore

final class IconImage {
	
	lazy var isDark: Bool = {
		return image.isDark()
	}()
	
	lazy var isBright: Bool = {
		return image.isBright()
	}()
	
	let image: RSImage
	let isSymbol: Bool
	let preferredColor: CGColor?

	init(_ image: RSImage, isSymbol: Bool = false, preferredColor: CGColor? = nil) {
		self.image = image
		self.isSymbol = isSymbol
		self.preferredColor = preferredColor
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
		guard let imageData = self.dataProvider?.data, let luminanceType = getLuminanceType(from: imageData) else {
			return false
		}
		return luminanceType == .bright
	}
	
	func isDark() -> Bool {
		guard let imageData = self.dataProvider?.data, let luminanceType = getLuminanceType(from: imageData) else {
			return false
		}
		return luminanceType == .dark
	}
	
	fileprivate func getLuminanceType(from data: CFData) -> ImageLuminanceType? {
		guard let ptr = CFDataGetBytePtr(data) else {
			return nil
		}

		let length = CFDataGetLength(data)
		var pixelCount = 0
		var totalLuminance = 0.0
		
		for i in stride(from: 0, to: length, by: 4) {
			
			let r = ptr[i]
			let g = ptr[i + 1]
			let b = ptr[i + 2]
			let a = ptr[i + 3]
			let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
			
			if Double(a) > 0 {
				totalLuminance += luminance
				pixelCount += 1
			}
			
		}
		
		let avgLuminance = totalLuminance / Double(pixelCount)
		if totalLuminance == 0 || avgLuminance < 40 {
			return .dark
		} else if avgLuminance > 180 {
			return .bright
		} else {
			return .regular
		}
	}
	
}


enum IconSize: Int, CaseIterable {
	case small = 1
	case medium = 2
	case large = 3
	
	private static let smallDimension = CGFloat(integerLiteral: 24)
	private static let mediumDimension = CGFloat(integerLiteral: 36)
	private static let largeDimension = CGFloat(integerLiteral: 48)

	var size: CGSize {
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
