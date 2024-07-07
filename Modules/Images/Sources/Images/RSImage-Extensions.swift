//
//  RSImage-Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Core

extension RSImage {
	
	private static let scaledMaxPixelSize: Int = {

		let maxIconSize = 48
#if os(iOS)
		let maxScreenScale = 3
#elseif os(macOS)
		let maxScreenScale = 2
#endif

		return maxIconSize * maxScreenScale
	}()

	static func scaledForIcon(_ data: Data) async -> RSImage? {

		RSImage.scaledForIconSync(data)
	}

	static func scaledForIconSync(_ data: Data) -> RSImage? {

		guard var cgImage = RSImage.scaleImage(data, maxPixelSize: Self.scaledMaxPixelSize) else {
			return nil
		}

		#if os(iOS)
		return RSImage(cgImage: cgImage)
		#else
		let size = NSSize(width: cgImage.width, height: cgImage.height)
		return RSImage(cgImage: cgImage, size: size)
		#endif		
	}
}
