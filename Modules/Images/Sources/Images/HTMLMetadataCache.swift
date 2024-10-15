//
//  HTMLMetadataCache.swift
//
//
//  Created by Brent Simmons on 10/13/24.
//

import Foundation
import Core
import Parser
import FoundationExtras

extension Notification.Name {
	// Sent when HTMLMetadata is cached. Posted on any thread.
	static let htmlMetadataAvailable = Notification.Name("htmlMetadataAvailable")
}

final class HTMLMetadataCache: Sendable {

	static let shared = HTMLMetadataCache()
	
	// Sent along with .htmlMetadataAvailable notification
	struct UserInfoKey {
		static let htmlMetadata = "htmlMetadata"
		static let url = "url" // String value
	}

	private struct HTMLMetadataCacheRecord: CacheRecord {
		let metadata: HTMLMetadata
		let dateCreated = Date()
	}

	private let cache = Cache<HTMLMetadataCacheRecord>(timeToLive: TimeInterval(days: 2), timeBetweenCleanups: TimeInterval(days: 1))

	subscript(_ url: String) -> HTMLMetadata? {
		get {
			return cache[url]?.metadata
		}
		set {
			guard let htmlMetadata = newValue else {
				return
			}
			let cacheRecord = HTMLMetadataCacheRecord(metadata: htmlMetadata)
			cache[url] = cacheRecord
			NotificationCenter.default.post(name: .htmlMetadataAvailable, object: self, userInfo: [UserInfoKey.htmlMetadata: htmlMetadata, UserInfoKey.url: url])
		}
	}
}
