//
//  FeedMetadata.swift
//  Account
//
//  Created by Brent Simmons on 3/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Articles

protocol FeedMetadataDelegate: class {
	func valueDidChange(_ feedMetadata: FeedMetadata, key: FeedMetadata.CodingKeys)
}

final class FeedMetadata: Codable {

	let feedID: String

	enum CodingKeys: String, CodingKey {
		case feedID
		case homePageURL
		case iconURL
		case faviconURL
		case name
		case editedName
		case authors
		case contentHash
		case conditionalGetInfo
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

	var name: String? {
		didSet {
			if name != oldValue {
				valueDidChange(.name)
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

	weak var delegate: FeedMetadataDelegate?

	init(feedID: String) {
		self.feedID = feedID
	}

	func valueDidChange(_ key: CodingKeys) {
		delegate?.valueDidChange(self, key: key)
	}
}
