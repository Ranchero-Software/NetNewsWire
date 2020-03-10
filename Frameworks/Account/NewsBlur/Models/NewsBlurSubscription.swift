//
//  NewsBlurSubscription.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-09.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

typealias NewsBlurSubscription = NewsBlurFeedsResponse.Subscription

struct NewsBlurFeedsResponse: Decodable {
	let subscriptions: [Subscription]
	let folders: [Folder]

	struct Subscription: Hashable, Codable {
		let title: String
		let feedId: Int
		let feedURL: String
		let siteURL: String?
		let favicon: String?
	}

	struct Folder: Hashable, Codable {
		let name: String
		let subscriptionIds: [Int]
	}
}

extension NewsBlurFeedsResponse {
	private enum CodingKeys: String, CodingKey {
		case feeds = "feeds"
		case folders = "flat_folders"
		// TODO: flat_folders_with_inactive
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		// Parse subscriptions
		var subscriptions: [Subscription] = []
		let subscriptionContainer = try container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: .feeds)
		try subscriptionContainer.allKeys.forEach { key in
			let subscription = try subscriptionContainer.decode(Subscription.self, forKey: key)
			subscriptions.append(subscription)
		}

		// Parse folders
		var folders: [Folder] = []
		let folderContainer = try container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: .folders)
		try folderContainer.allKeys.forEach { key in
			let subscriptionIds = try folderContainer.decode([Int].self, forKey: key)
			let folder = Folder(name: key.stringValue, subscriptionIds: subscriptionIds)

			folders.append(folder)
		}

		self.subscriptions = subscriptions
		self.folders = folders
	}
}

extension NewsBlurFeedsResponse.Subscription {
	private enum CodingKeys: String, CodingKey {
		case title = "feed_title"
		case feedId = "id"
		case feedURL = "feed_address"
		case siteURL = "feed_link"
		case favicon = "favicon_url"
	}
}

fileprivate struct GenericCodingKeys: CodingKey {
	var stringValue: String

	init?(stringValue: String) {
		self.stringValue = stringValue
	}

	var intValue: Int? {
		return nil
	}

	init?(intValue: Int) {
		return nil
	}
}
