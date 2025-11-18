//
//  FeedMetadata.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Articles

@MainActor protocol FeedMetadataDelegate: AnyObject {
	func valueDidChange(_ feedMetadata: FeedMetadata, key: FeedMetadata.CodingKeys)
}

@MainActor final class FeedMetadata: Codable {
	enum CodingKeys: String, CodingKey {
		case feedID
		case homePageURL
		case iconURL
		case faviconURL
		case editedName
		case authors
		case contentHash
		case isNotifyAboutNewArticles
		case isArticleExtractorAlwaysOn
		case conditionalGetInfo
		case conditionalGetInfoDate
		case cacheControlInfo
		case externalID = "subscriptionID"
		case folderRelationship
		case lastCheckDate
	}

	var feedID: String {
		didSet {
			if feedID != oldValue {
				valueDidChange(.feedID)
			}
		}
	}

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

	var isNotifyAboutNewArticles: Bool? {
		didSet {
			if isNotifyAboutNewArticles != oldValue {
				valueDidChange(.isNotifyAboutNewArticles)
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
				if conditionalGetInfo == nil {
					conditionalGetInfoDate = nil
				} else {
					conditionalGetInfoDate = Date()
				}
			}
		}
	}

	var conditionalGetInfoDate: Date? {
		  didSet {
			  if conditionalGetInfoDate != oldValue {
				  valueDidChange(.conditionalGetInfoDate)
			  }
		  }
	  }

	var cacheControlInfo: CacheControlInfo? {
		didSet {
			if cacheControlInfo != oldValue {
				valueDidChange(.cacheControlInfo)
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

	/// Last time an attempt was made to read the feed.
	/// (Not necessarily a successful attempt.)
	var lastCheckDate: Date? {
		didSet {
			if lastCheckDate != oldValue {
				valueDidChange(.lastCheckDate)
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
