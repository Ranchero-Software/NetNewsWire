//
//  FeedIconImageLoader.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account

final class FeedIconImageLoader: ObservableObject {
	
	@Published var image: IconImage?
	private var feed: Feed?
	private var cancellables = Set<AnyCancellable>()
	
	init() {
		NotificationCenter.default.publisher(for: .FaviconDidBecomeAvailable).sink {  [weak self] _ in
			self?.fetchImage()
		}.store(in: &cancellables)
		
		
		NotificationCenter.default.publisher(for: .WebFeedIconDidBecomeAvailable).sink {  [weak self] note in
			guard let feed = self?.feed as? WebFeed, let noteFeed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed, feed == noteFeed else {
				return
			}
			self?.fetchImage()
		}.store(in: &cancellables)
	}
	
	func loadImage(for feed: Feed) {
		guard image == nil else { return }
		self.feed = feed
		fetchImage()
	}
	
}

private extension FeedIconImageLoader {
	
	func fetchImage() {
		guard let feed = feed else { return }
		image = IconImageCache.shared.imageForFeed(feed)
	}
}
