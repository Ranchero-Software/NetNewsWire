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
		
		if cgImage.width < avatarSize || cgImage.height < avatarSize {
			cgImage = RSImage.compositeAvatar(cgImage)
		}
		
		#if os(iOS)
		return RSImage(cgImage: cgImage)
		#else
		let size = NSSize(width: cgImage.width, height: cgImage.height)
		return RSImage(cgImage: cgImage, size: size)
		#endif
		
	}
	
}

private extension RSImage {
	
	#if os(iOS)
	
	static func compositeAvatar(_ avatar: CGImage) -> CGImage {
		let rect = CGRect(x: 0, y: 0, width: avatarSize, height: avatarSize)
		UIGraphicsBeginImageContext(rect.size)
		if let context = UIGraphicsGetCurrentContext() {
			context.setFillColor(AppAssets.avatarBackgroundColor.cgColor)
			context.fill(rect)
			context.translateBy(x: 0.0, y: CGFloat(integerLiteral: avatarSize));
			context.scaleBy(x: 1.0, y: -1.0)
			let avatarRect = CGRect(x: (avatarSize - avatar.width) / 2, y: (avatarSize - avatar.height) / 2, width: avatar.width, height: avatar.height)
			context.draw(avatar, in: avatarRect)
		}
		let img = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return img!.cgImage!
	}
	
	#else

	static func compositeAvatar(_ avatar: CGImage) -> CGImage {
		var resultRect = CGRect(x: 0, y: 0, width: avatarSize, height: avatarSize)
		let resultImage = NSImage(size: resultRect.size)
		
		resultImage.lockFocus()
		if let context = NSGraphicsContext.current?.cgContext {
			if NSApplication.shared.effectiveAppearance.isDarkMode {
				context.setFillColor(AppAssets.avatarDarkBackgroundColor.cgColor)
			} else {
				context.setFillColor(AppAssets.avatarLightBackgroundColor.cgColor)
			}
			context.fill(resultRect)
			let avatarRect = CGRect(x: (avatarSize - avatar.width) / 2, y: (avatarSize - avatar.height) / 2, width: avatar.width, height: avatar.height)
			context.draw(avatar, in: avatarRect)
		}
		resultImage.unlockFocus()
		
		return resultImage.cgImage(forProposedRect: &resultRect, context: nil, hints: nil)!
	}

	#endif
	
}
