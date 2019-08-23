//
//  SharingServiceDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/7/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

@objc final class SharingServiceDelegate: NSObject, NSSharingServiceDelegate {

	weak var window: NSWindow?
	
	init(_ window: NSWindow?) {
		self.window = window
	}

	func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
		sharingService.subject = items
			.compactMap { item in
				let writer = item as? ArticlePasteboardWriter
				return writer?.article.title
			}
			.joined(separator: ", ")
	}
	
	func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any], sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
		return window
	}
	
}
