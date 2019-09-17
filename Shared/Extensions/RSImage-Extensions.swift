//
//  RSImage-Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

extension RSImage {
	
	static let avatarSize = 48
	
	static func scaledForAvatar(_ data: Data, imageResultBlock: @escaping (RSImage?) -> Void) {
		DispatchQueue.global().async {
			let image = RSImage.scaledForAvatar(data)
			DispatchQueue.main.async {
				imageResultBlock(image)
			}
		}
	}

	static func scaledForAvatar(_ data: Data) -> RSImage? {
		let scaledMaxPixelSize = Int(ceil(CGFloat(RSImage.avatarSize) * RSScreen.mainScreenScale))
		guard var cgImage = RSImage.scaleImage(data, maxPixelSize: scaledMaxPixelSize) else {
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
