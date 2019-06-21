//
//  AppAssets.swift
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

struct AppAssets {

	static var genericFeedImage: RSImage? = {
		let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns"
		let image = RSImage(contentsOfFile: path)
		return image
	}()

	static var timelineStar: RSImage! = {
		return RSImage(named: .timelineStar)
	}()

	static var accountLocal: RSImage! = {
		return RSImage(named: "accountLocal")
	}()

	static var accountFeedbin: RSImage! = {
		return RSImage(named: "accountFeedbin")
	}()
	
	static var accountFreshRSS: RSImage! = {
		return RSImage(named: "accountFreshRSS")
	}()
	
	static var faviconTemplateImage: RSImage = {
		return RSImage(named: "faviconTemplateImage")!
	}()

	static var avatarLightBackgroundColor: NSColor = {
		return NSColor(named: NSColor.Name("avatarLightBackgroundColor"))!
	}()

	static var avatarDarkBackgroundColor: NSColor = {
		return NSColor(named: NSColor.Name("avatarDarkBackgroundColor"))!
	}()
}
