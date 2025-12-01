//
//  ArticleFetcherType.swift
//  Account
//
//  Created by Maurice Parker on 11/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedIdentifiable {
	var feedID: FeedIdentifier? { get }
}

public enum FeedIdentifier: CustomStringConvertible, Hashable, Equatable {
	case smartFeed(String) // String is a unique identifier
	case script(String) // String is a unique identifier
	case webFeed(String, String) // accountID, webFeedID
	case folder(String, String) // accountID, folderName

	private struct TypeName {
		static let smartFeed = "smartFeed"
		static let script = "script"
		static let feed = "feed"
		static let folder = "folder"
	}

	private struct Key {
		static let typeName = "type"
		static let id = "id"
		static let accountID = "accountID"
		static let feedID = "webFeedID"
		static let folderName = "folderName"
	}

	private var typeName: String {
		switch self {
		case .smartFeed:
			return TypeName.smartFeed
		case .script:
			return TypeName.script
		case .webFeed:
			return TypeName.feed
		case .folder:
			return TypeName.folder
		}
	}

	public var description: String {
		switch self {
		case .smartFeed(let id):
			return "\(typeName): \(id)"
		case .script(let id):
			return "\(typeName): \(id)"
		case .webFeed(let accountID, let webFeedID):
			return "\(typeName): \(accountID)_\(webFeedID)"
		case .folder(let accountID, let folderName):
			return "\(typeName): \(accountID)_\(folderName)"
		}
	}
	
	public var userInfo: [String: String] {
		var d = [Key.typeName: typeName]
		
		switch self {
		case .smartFeed(let id):
			d[Key.id] = id
		case .script(let id):
			d[Key.id] = id
		case .webFeed(let accountID, let webFeedID):
			d[Key.accountID] = accountID
			d[Key.feedID] = webFeedID
		case .folder(let accountID, let folderName):
			d[Key.accountID] = accountID
			d[Key.folderName] = folderName
		}

		return d
	}

	public init?(userInfo: [String: String]) {
		guard let type = userInfo[Key.typeName] else {
			return nil
		}

		switch type {
		case TypeName.smartFeed:
			guard let id = userInfo[Key.id] else {
				return nil
			}
			self = FeedIdentifier.smartFeed(id)
		case TypeName.script:
			guard let id = userInfo[Key.id] else {
				return nil
			}
			self = FeedIdentifier.script(id)
		case TypeName.feed:
			guard let accountID = userInfo[Key.accountID], let webFeedID = userInfo[Key.feedID] else {
				return nil
			}
			self = FeedIdentifier.webFeed(accountID, webFeedID)
		case TypeName.folder:
			guard let accountID = userInfo[Key.accountID], let folderName = userInfo[Key.folderName] else {
				return nil
			}
			self = FeedIdentifier.folder(accountID, folderName)
		default:
			assertionFailure("Expected valid FeedIdentifier.userInfo but got \(userInfo)")
			return nil
		}
	}
}
