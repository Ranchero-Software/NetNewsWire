//
//  AppImages.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

extension NSImage.Name {
	static let star = NSImage.Name("star")
	static let timelineStar = NSImage.Name("timelineStar")
}

struct AppImages {

	static var genericFeedImage: RSImage? = {
		let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns"
		let image = RSImage(contentsOfFile: path)
		return image
	}()

	static var timelineStar: RSImage! = {
		return RSImage(named: .timelineStar)
	}()
}
