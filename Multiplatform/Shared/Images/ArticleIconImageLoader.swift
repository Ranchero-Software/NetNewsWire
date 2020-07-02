//
//  ArticleIconImageLoader.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles

final class ArticleIconImageLoader: ObservableObject {
	
	private var article: Article?
	
	@Published var image: IconImage?
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
	}
	
	func loadImage(for article: Article) {
		guard image == nil else { return }
		self.article = article
		image = article.iconImage()
	}
	
}

private extension ArticleIconImageLoader {
	
	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		guard let article = article else { return }
		image = article.iconImage()
	}

	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		guard let article = article, let noteFeed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed, noteFeed == article.webFeed else {
			return
		}
		image = article.iconImage()
	}
	
	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		guard let article = article, let authors = article.authors, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}

		for author in authors {
			if author.avatarURL == avatarURL {
				image = article.iconImage()
				return
			}
		}
	}
}
