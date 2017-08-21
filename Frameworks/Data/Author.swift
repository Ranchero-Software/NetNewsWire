//
//  Author.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

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
	
	public static func ==(lhs: Author, rhs: Author) -> Bool {

		return lhs.hashValue == rhs.hashValue && lhs.authorID == rhs.authorID
	}
}
