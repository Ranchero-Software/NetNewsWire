//
//  Author.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct Author: Hashable {

	public let authorID: String // calculated
	public let name: String?
	public let url: String?
	public let avatarURL: String?
	public let emailAddress: String?
	public let hashValue: Int
	
	public init?(authorID: String?, name: String?, url: String?, avatarURL: String?, emailAddress: String?) {

		if name == nil && url == nil && emailAddress == nil {
			return nil
		}
		self.name = name
		self.url = url
		self.avatarURL = avatarURL
		self.emailAddress = emailAddress

		var s = name ?? ""
		s += url ?? ""
		s += avatarURL ?? ""
		s += emailAddress ?? ""
		self.hashValue = s.hashValue

		if let authorID = authorID {
			self.authorID = authorID
		}
		else {
			self.authorID = databaseIDWithString(s)
		}
	}

	public struct Key {
		static let authorID = "authorID"
		static let name = "name"
		static let url = "url"
		static let avatarURL = "avatarURL"
		static let emailAddress = "emailAddress"
	}

	public init?(dictionary: [String: Any]) {

		self.init(authorID: dictionary[Key.authorID] as? String, name: dictionary[Key.name] as? String, url: dictionary[Key.url] as? String, avatarURL: dictionary[Key.avatarURL] as? String, emailAddress: dictionary[Key.emailAddress] as? String)
	}

	public var dictionary: [String: Any] {

		var d = [String: Any]()

		d[Key.authorID] = authorID

		if let name = name {
			d[Key.name] = name
		}
		if let url = url {
			d[Key.url] = url
		}
		if let avatarURL = avatarURL {
			d[Key.avatarURL] = avatarURL
		}
		if let emailAddress = emailAddress {
			d[Key.emailAddress] = emailAddress
		}

		return d
	}

	public static func ==(lhs: Author, rhs: Author) -> Bool {

		return lhs.hashValue == rhs.hashValue && lhs.authorID == rhs.authorID
	}

	public static func authorsWithDiskArray(_ diskArray: [[String: Any]]) -> Set<Author>? {

		let authors = diskArray.compactMap { Author(dictionary: $0) }
		return authors.isEmpty ? nil : Set(authors)
	}
}

extension Set where Element == Author {

	public func diskArray() -> [[String: Any]]? {

		if self.isEmpty {
			return nil
		}
		return self.map{ $0.dictionary }
	}
}
