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

	static var appIconImage: RSImage? {
		#if os(macOS)
		return RSImage(named: NSImage.applicationIconName)
		#elseif os(iOS)
		// https://stackoverflow.com/a/51241158/14256
		if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
			let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
			let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
			let lastIcon = iconFiles.last {
			return RSImage(named: lastIcon)
		}
		return nil
		#endif
	}
}

extension IconImage {
	static let appIcon: IconImage? = {
		if let image = RSImage.appIconImage {
			return IconImage(image)
		}
		return nil
	}()

	static let nnwFeedIcon = IconImage(Assets.Images.nnwFeedIcon)
}

// MARK: - IconScalerQueue

private final class IconScalerQueue: Sendable {

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
