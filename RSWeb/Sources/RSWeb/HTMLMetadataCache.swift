//
//  HTMLMetadataCache.swift
//
//
//  Created by Brent Simmons on 10/13/24.
//

import Foundation
import Core
@preconcurrency import RSParser

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
		let metadata: RSHTMLMetadata
		let dateCreated = Date()
	}

	private let cache = Cache<HTMLMetadataCacheRecord>(timeToLive: TimeInterval(hours: 21), timeBetweenCleanups: TimeInterval(hours: 10))

	subscript(_ url: String) -> RSHTMLMetadata? {
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
