//
//  AppImages.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

extension NSImage.Name {
	static let star = NSImage.Name(rawValue: "star")
	static let unstar = NSImage.Name(rawValue: "unstar")
	static let timelineStar = NSImage.Name(rawValue: "timelineStar")
}

struct AppImages {

	static var genericFeedImage: NSImage? = {
		let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns"
		let image = NSImage(contentsOfFile: path)
		return image
	}()

	static var timelineStar: NSImage! = {
		return NSImage(named: .timelineStar)
	}()
}
