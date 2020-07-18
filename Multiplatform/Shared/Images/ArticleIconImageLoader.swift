//
//  ArticleIconImageLoader.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Combine
import Account
import Articles

final class ArticleIconImageLoader: ObservableObject {
	
	@Published var image: IconImage?
	private var article: Article?
	private var cancellables = Set<AnyCancellable>()

	init() {
		NotificationCenter.default.publisher(for: .FaviconDidBecomeAvailable).sink {  [weak self] _ in
			guard let self = self, let article = self.article else { return }
			self.image = article.iconImage()
		}.store(in: &cancellables)

		NotificationCenter.default.publisher(for: .WebFeedIconDidBecomeAvailable).sink {  [weak self] note in
			guard let self = self, let article = self.article, let noteFeed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed, noteFeed == article.webFeed else {
				return
			}
			self.image = article.iconImage()
		}.store(in: &cancellables)

		NotificationCenter.default.publisher(for: .AvatarDidBecomeAvailable).sink {  [weak self] note in
			guard let self = self, let article = self.article, let authors = article.authors, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
				return
			}
			for author in authors {
				if author.avatarURL == avatarURL {
					self.image = article.iconImage()
					return
				}
			}
		}.store(in: &cancellables)
	}
	
	func loadImage(for article: Article) {
		guard image == nil else { return }
		self.article = article
		image = article.iconImage()
	}
	
}
