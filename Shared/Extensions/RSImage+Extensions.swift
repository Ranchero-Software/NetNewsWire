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
	static let maxIconPixelSize = Int(ceil(48.0 * RSScreen.maxScreenScale))

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
