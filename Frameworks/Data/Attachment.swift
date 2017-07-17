//
//  Attachment.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct Attachment: Hashable {

	public let databaseID: String // Calculated
	public let articleID: String // Article.databaseID
	public let url: String
	public let mimeType: String?
	public let title: String?
	public let sizeInBytes: Int?
	public let durationInSeconds: Int?
	public let hashValue: Int

	public init(databaseID: String?, articleID: String, url: String, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?) {

		self.articleID = articleID
		self.url = url
		self.mimeType = mimeType
		self.title = title
		self.sizeInBytes = sizeInBytes
		self.durationInSeconds = durationInSeconds

		var s = articleID + url
		s += mimeType ?? ""
		s += title ?? ""
		if let sizeInBytes = sizeInBytes {
			s += "\(sizeInBytes)"
		}
		if let durationInSeconds = durationInSeconds {
			s += "\(durationInSeconds)"
		}
		self.hashValue = s.hashValue

		if let databaseID = databaseID {
			self.databaseID = databaseID
		}
		else {
			self.databaseID = databaseIDWithString(s)
		}
	}

	public static func ==(lhs: Attachment, rhs: Attachment) -> Bool {

		return lhs.sizeInBytes == rhs.sizeInBytes && lhs.url == rhs.url && lhs.mimeType == rhs.mimeType && lhs.title == rhs.title && lhs.durationInSeconds == rhs.durationInSeconds
	}
}
