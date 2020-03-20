//
//  RSImage-Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import RSCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

import RSCore

extension RSImage {
	
	static let maxIconSize = 48
	
	static func scaledForIcon(_ data: Data, imageResultBlock: @escaping ImageResultBlock) {
		IconScalerQueue.shared.scaledForIcon(data, imageResultBlock)
	}

	static func scaledForIcon(_ data: Data) -> RSImage? {
		let scaledMaxPixelSize = Int(ceil(CGFloat(RSImage.maxIconSize) * RSScreen.maxScreenScale))
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

// MARK: - IconScalerQueue

private class IconScalerQueue {

	static let shared = IconScalerQueue()

	private let queue: DispatchQueue = {
		let q = DispatchQueue(label: "IconScaler", attributes: .initiallyInactive)
		q.setTarget(queue: DispatchQueue.global(qos: .default))
		q.activate()
		return q
	}()

	func scaledForIcon(_ data: Data, _ imageResultBlock: @escaping ImageResultBlock) {
		queue.async {
			let image = RSImage.scaledForIcon(data)
			DispatchQueue.main.async {
				imageResultBlock(image)
			}
		}
	}
}
