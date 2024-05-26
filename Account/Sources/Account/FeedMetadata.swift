//
//  FeedMetadata.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Articles

protocol FeedMetadataDelegate: AnyObject {
	func valueDidChange(_ feedMetadata: FeedMetadata, key: FeedMetadata.CodingKeys)
}

final class FeedMetadata: Codable {

	enum CodingKeys: String, CodingKey {
		case feedID = "feedID"
		case homePageURL
		case iconURL
		case faviconURL
		case editedName
		case authors
		case contentHash
		case shouldSendUserNotificationForNewArticles = "isNotifyAboutNewArticles"
		case isArticleExtractorAlwaysOn
		case conditionalGetInfo
		case sinceToken
		case externalID = "subscriptionID"
		case folderRelationship
	}

	let feedID: String

	var homePageURL: String? {
		didSet {
			if homePageURL != oldValue {
				valueDidChange(.homePageURL)
			}
		}
	}

	var iconURL: String? {
		didSet {
			if iconURL != oldValue {
				valueDidChange(.iconURL)
			}
		}
	}

	var faviconURL: String? {
		didSet {
			if faviconURL != oldValue {
				valueDidChange(.faviconURL)
			}
		}
	}

	var editedName: String? {
		didSet {
			if editedName != oldValue {
				valueDidChange(.editedName)
			}
		}
	}

	var contentHash: String? {
		didSet {
			if contentHash != oldValue {
				valueDidChange(.contentHash)
			}
		}
	}
	
	var shouldSendUserNotificationForNewArticles: Bool? {
		didSet {
			if shouldSendUserNotificationForNewArticles != oldValue {
				valueDidChange(.shouldSendUserNotificationForNewArticles)
			}
		}
	}

	var isArticleExtractorAlwaysOn: Bool? {
		didSet {
			if isArticleExtractorAlwaysOn != oldValue {
				valueDidChange(.isArticleExtractorAlwaysOn)
			}
		}
	}

	var authors: [Author]? {
		didSet {
			if authors != oldValue {
				valueDidChange(.authors)
			}
		}
	}

	var conditionalGetInfo: HTTPConditionalGetInfo? {
		didSet {
			if conditionalGetInfo != oldValue {
				valueDidChange(.conditionalGetInfo)
			}
		}
	}
	
	var sinceToken: String? {
		didSet {
			if externalID != oldValue {
				valueDidChange(.externalID)
			}
		}
	}
	
	var externalID: String? {
		didSet {
			if externalID != oldValue {
				valueDidChange(.externalID)
			}
		}
	}
	
	// Folder Name: Sync Service Relationship ID
	var folderRelationship: [String: String]? {
		didSet {
			if folderRelationship != oldValue {
				valueDidChange(.folderRelationship)
			}
		}
	}

	weak var delegate: FeedMetadataDelegate?

	init(feedID: String) {
		self.feedID = feedID
	}

	func valueDidChange(_ key: CodingKeys) {
		delegate?.valueDidChange(self, key: key)
	}
}
