//
//  AccountMetadata.swift
//  Account
//
//  Created by Brent Simmons on 3/3/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

protocol AccountMetadataDelegate: class {
	func valueDidChange(_ accountMetadata: AccountMetadata, key: AccountMetadata.CodingKeys)
}

final class AccountMetadata: Codable {

	enum CodingKeys: String, CodingKey {
		case name
		case isActive
		case username
		case conditionalGetInfo
		case lastArticleFetch
		case endpointURL
	}

	var name: String? {
		didSet {
			if name != oldValue {
				valueDidChange(.name)
			}
		}
	}
	
	var isActive: Bool = true {
		didSet {
			if isActive != oldValue {
				valueDidChange(.isActive)
			}
		}
	}
	
	var username: String? {
		didSet {
			if username != oldValue {
				valueDidChange(.username)
			}
		}
	}
	
	var conditionalGetInfo = [String: HTTPConditionalGetInfo]() {
		didSet {
			if conditionalGetInfo != oldValue {
				valueDidChange(.conditionalGetInfo)
			}
		}
	}
	
	var lastArticleFetch: Date? {
		didSet {
			if lastArticleFetch != oldValue {
				valueDidChange(.lastArticleFetch)
			}
		}
	}
	
	var endpointURL: URL? {
		didSet {
			if endpointURL != oldValue {
				valueDidChange(.endpointURL)
			}
		}
	}

	weak var delegate: AccountMetadataDelegate?
	
	func valueDidChange(_ key: CodingKeys) {
		delegate?.valueDidChange(self, key: key)
	}
}
