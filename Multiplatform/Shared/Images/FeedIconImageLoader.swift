//
//  FeedIconImageLoader.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

final class FeedIconImageLoader: ObservableObject {
	
	private var feed: Feed?
	
	@Published var image: IconImage?
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
	}
	
	func loadImage(for feed: Feed) {
		guard image == nil else { return }
		self.feed = feed
		fetchImage()
	}
	
}

private extension FeedIconImageLoader {
	
	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		fetchImage()
	}

	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		guard let feed = feed as? WebFeed, let noteFeed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed, feed == noteFeed else {
			return
		}
		fetchImage()
	}
	
	func fetchImage() {
		if let webFeed = feed as? WebFeed {
			if let feedIconImage = appDelegate.webFeedIconDownloader.icon(for: webFeed) {
				image = feedIconImage
				return
			}
			if let faviconImage = appDelegate.faviconDownloader.faviconAsIcon(for: webFeed) {
				image = faviconImage
				return
			}
		}
		
		if let smallIconProvider = feed as? SmallIconProvider {
			image = smallIconProvider.smallIcon
		}
	}
	
}
