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
	
	static var accountFeedly: RSImage! = {
		return RSImage(named: "accountFeedly")
	}()
	
	static var accountFreshRSS: RSImage! = {
		return RSImage(named: "accountFreshRSS")
	}()
	
	static var articleExtractor: RSImage! = {
		return RSImage(named: "articleExtractor")
	}()
	
	static var articleExtractorError: RSImage! = {
		return RSImage(named: "articleExtractorError")
	}()
	
	static var articleExtractorProgress1: RSImage! = {
		return RSImage(named: "articleExtractorProgress1")
	}()
	
	static var articleExtractorProgress2: RSImage! = {
		return RSImage(named: "articleExtractorProgress2")
	}()
	
	static var articleExtractorProgress3: RSImage! = {
		return RSImage(named: "articleExtractorProgress3")
	}()
	
	static var articleExtractorProgress4: RSImage! = {
		return RSImage(named: "articleExtractorProgress4")
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

	static var searchFeedImage: RSImage = {
		return RSImage(named: NSImage.smartBadgeTemplateName)!
	}()

	static var starredFeedImage: RSImage = {
		return RSImage(named: NSImage.smartBadgeTemplateName)!
	}()

	static var todayFeedImage: RSImage = {
		return RSImage(named: NSImage.smartBadgeTemplateName)!
	}()

	static var unreadFeedImage: RSImage = {
		return RSImage(named: NSImage.smartBadgeTemplateName)!
	}()

}
