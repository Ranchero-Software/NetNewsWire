//
//  Author.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct Author: Codable, Hashable, Sendable {
	public let authorID: String // calculated
	public let name: String?
	public let url: String?
	public let avatarURL: String?
	public let emailAddress: String?

	public init?(authorID: String?, name: String?, url: String?, avatarURL: String?, emailAddress: String?) {
		if name == nil && url == nil && emailAddress == nil {
			return nil
		}
		self.name = name
		self.url = url
		self.avatarURL = avatarURL
		self.emailAddress = emailAddress

		if let authorID = authorID {
			self.authorID = authorID
		} else {
			var s = name ?? ""
			s += url ?? ""
			s += avatarURL ?? ""
			s += emailAddress ?? ""
			self.authorID = databaseIDWithString(s)
		}
	}

	public static func authorsWithJSON(_ data: Data) -> Set<Author>? {
		// This is JSON stored in the database, not the JSON Feed version of an author.
		// Sometimes this shows up as the site of a leak. It’s a real leak, but small.
		// The leak appears to be in Apple code.
		let decoder = JSONDecoder()
		do {
			let authors = try decoder.decode([Author].self, from: data)
			return AuthorCache.shared.add(Set(authors))
		} catch {
			assertionFailure("JSON representation of Author array could not be decoded, error: \(error)")
		}
		return nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(authorID)
	}

	// MARK: - Equatable

	static public func ==(lhs: Author, rhs: Author) -> Bool {
		// The authorID is a calculation based on all the properties,
		// and so it’s a quick shortcut to determine equality.
		return lhs.authorID == rhs.authorID
	}
}

extension Set where Element == Author {

	public func json() -> String? {
		let encoder = JSONEncoder()
		do {
			let jsonData = try encoder.encode(Array(self))
			return String(data: jsonData, encoding: .utf8)
		} catch {
			assertionFailure("JSON representation of Author array could not be encoded: \(self) error: \(error)")
		}
		return nil
	}
}
