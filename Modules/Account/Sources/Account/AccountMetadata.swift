//
//  AccountMetadata.swift
//  Account
//
//  Created by Brent Simmons on 3/3/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

protocol AccountMetadataDelegate: AnyObject {
	@MainActor func valueDidChange(_ accountMetadata: AccountMetadata, key: AccountMetadata.CodingKeys)
}

@MainActor final class AccountMetadata: @MainActor Codable {

	enum CodingKeys: String, CodingKey {
		case name
		case isActive
		case username
		case conditionalGetInfo
		case lastArticleFetchStartTime = "lastArticleFetch"
		case lastArticleFetchEndTime
		case endpointURL
		case externalID
		case performedApril2020RetentionPolicyChange
	}

	@MainActor var name: String? {
		didSet {
			if name != oldValue {
				valueDidChange(.name)
			}
		}
	}

	@MainActor var isActive: Bool = true {
		didSet {
			if isActive != oldValue {
				valueDidChange(.isActive)
			}
		}
	}

	@MainActor var username: String? {
		didSet {
			if username != oldValue {
				valueDidChange(.username)
			}
		}
	}

	@MainActor var conditionalGetInfo = [String: HTTPConditionalGetInfo]() {
		didSet {
			if conditionalGetInfo != oldValue {
				valueDidChange(.conditionalGetInfo)
			}
		}
	}

	@MainActor var lastArticleFetchStartTime: Date? {
		didSet {
			if lastArticleFetchStartTime != oldValue {
				valueDidChange(.lastArticleFetchStartTime)
			}
		}
	}

	@MainActor var lastArticleFetchEndTime: Date? {
		didSet {
			if lastArticleFetchEndTime != oldValue {
				valueDidChange(.lastArticleFetchEndTime)
			}
		}
	}

	@MainActor var endpointURL: URL? {
		didSet {
			if endpointURL != oldValue {
				valueDidChange(.endpointURL)
			}
		}
	}

	var performedApril2020RetentionPolicyChange: Bool? // No longer used.

	@MainActor var externalID: String? {
		didSet {
			if externalID != oldValue {
				valueDidChange(.externalID)
			}
		}
	}

	@MainActor weak var delegate: AccountMetadataDelegate?

	@MainActor func valueDidChange(_ key: CodingKeys) {
		delegate?.valueDidChange(self, key: key)
	}
}
