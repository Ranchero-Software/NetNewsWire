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


	static func scaledForIcon(_ data: Data, imageResultBlock: @escaping ImageResultBlock) {
		IconScalerQueue.shared.scaledForIcon(data, imageResultBlock)
	}

	static func scaledForIcon(_ data: Data) -> RSImage? {

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

// MARK: - IconScalerQueue

private final class IconScalerQueue: @unchecked Sendable {

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
