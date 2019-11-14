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
	
	static var articleExtractorInactiveDark: RSImage! = {
		return RSImage(named: "articleExtractorInactiveDark")
	}()
	
	static var articleExtractorInactiveLight: RSImage! = {
		return RSImage(named: "articleExtractorInactiveLight")
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

	static var iconLightBackgroundColor: NSColor = {
		return NSColor(named: NSColor.Name("iconLightBackgroundColor"))!
	}()

	static var iconDarkBackgroundColor: NSColor = {
		return NSColor(named: NSColor.Name("iconDarkBackgroundColor"))!
	}()

	static var masterFolderImage: IconImage = {
		return IconImage(RSImage(named: NSImage.folderName)!)
	}()

	static var searchFeedImage: IconImage = {
		return IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!)
	}()

	static var starredFeedImage: IconImage = {
		return IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!)
	}()

	static var todayFeedImage: IconImage = {
		return IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!)
	}()

	static var unreadFeedImage: IconImage = {
		return IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!)
	}()

	static var swipeMarkReadImage: RSImage = {
		return RSImage(named: "swipeMarkRead")!
	}()

	static var swipeMarkUnreadImage: RSImage = {
		return RSImage(named: "swipeMarkUnread")!
	}()

	static var swipeMarkStarredImage: RSImage = {
		return RSImage(named: "swipeMarkStarred")!
	}()

	static var swipeMarkUnstarredImage: RSImage = {
		return RSImage(named: "swipeMarkUnstarred")!
	}()
	
}
